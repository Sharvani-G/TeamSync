import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const String _webVapidKey = String.fromEnvironment(
    'TEAMSYNC_FCM_VAPID_KEY',
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;
  final Map<String, Stream<List<ProjectNotificationItem>>>
      _notificationStreams = {};
  final Map<String, Stream<int>> _unreadNotificationStreams = {};
  bool _pushInitialized = false;
  void Function(String route, Map<String, dynamic> data)?
      _notificationTapHandler;

  Stream<T> _retryingStream<T>(
    String label,
    Stream<T> Function() createStream, {
    Duration initialDelay = const Duration(milliseconds: 300),
    Duration maxDelay = const Duration(seconds: 5),
  }) async* {
    var attempt = 0;

    while (true) {
      try {
        await for (final value in createStream()) {
          attempt = 0;
          yield value;
        }
        return;
      } catch (e) {
        attempt += 1;
        final delayMs = initialDelay.inMilliseconds * attempt;
        final clampedDelayMs = delayMs.clamp(
          initialDelay.inMilliseconds,
          maxDelay.inMilliseconds,
        );
        print('⚠️ $label stream error: $e');
        await Future.delayed(Duration(milliseconds: clampedDelayMs));
      }
    }
  }

  Future<void> initializePushNotifications({
    void Function(String route, Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (_pushInitialized) {
      return;
    }

    _pushInitialized = true;
    _notificationTapHandler = onNotificationTap;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      FirebaseMessaging.onMessage.listen((message) {
        print('ℹ️ FCM foreground message: ${message.messageId ?? 'unknown'}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('ℹ️ FCM opened message: ${message.messageId ?? 'unknown'}');
        _handleNotificationTap(message);
      });

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _authSubscription = _auth.authStateChanges().listen((user) async {
        if (user == null) {
          return;
        }

        await _syncDeviceToken(user.uid);
      });

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _syncDeviceToken(currentUser.uid);
      }
    } catch (e) {
      print('⚠️ FCM initialization failed: $e');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> _syncDeviceToken(String userId) async {
    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey,
            )
          : await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _firestore.collection('users').doc(userId).set({
        'fcm_token': token,
      }, SetOptions(merge: true));

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(userId).set({
          'fcm_token': newToken,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      print('⚠️ Unable to sync FCM token: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final route = _resolveRouteFromPushData(data);
    _notificationTapHandler?.call(route, data);
  }

  String _resolveRouteFromPushData(Map<String, dynamic> data) {
    final explicitRoute = data['route']?.toString().trim() ?? '';
    if (explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    final projectId = data['projectId']?.toString().trim() ?? '';
    final type = data['type']?.toString().trim() ?? '';
    if (projectId.isNotEmpty) {
      if (type == 'chat_message') {
        return '/project/$projectId/workspace/chat';
      }
      if (type == 'call_started' || type == 'incoming_call' || type == 'webrtc:incoming-call') {
        return '/project/$projectId/workspace/calls';
      }
      return '/project/$projectId';
    }

    return '/notifications';
  }

  Stream<List<ProjectNotificationItem>> watchMyNotifications() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(<ProjectNotificationItem>[]).asBroadcastStream();
    }

    final cached = _notificationStreams[currentUserId];
    if (cached != null) {
      return cached;
    }

    final stream = _retryingStream<List<ProjectNotificationItem>>(
      'watchMyNotifications($currentUserId)',
      () => _firestore
          .collection('notifications')
          .where('recipient_uid', isEqualTo: currentUserId)
          .orderBy('created_at', descending: true)
          .limit(30)
          .snapshots()
          .map((snapshot) {
        final items = <ProjectNotificationItem>[];

        for (final doc in snapshot.docs) {
          final item = _parseNotificationItem(doc);
          if (item.deliverAt != null &&
              item.deliverAt!.isAfter(DateTime.now())) {
            continue;
          }
          items.add(item);
        }

        return items;
      }),
    ).asBroadcastStream();

    _notificationStreams[currentUserId] = stream;
    return stream;
  }

  Stream<int> watchUnreadNotificationCount() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(0).asBroadcastStream();
    }

    final cached = _unreadNotificationStreams[currentUserId];
    if (cached != null) {
      return cached;
    }

    final stream = _retryingStream<int>(
      'watchUnreadNotificationCount($currentUserId)',
      () => _firestore
          .collection('notifications')
          .where('recipient_uid', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        var unreadCount = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final deliverAt = _parseDateTime(data['deliverAt']);
          final isDeliverable =
              deliverAt == null || !deliverAt.isAfter(DateTime.now());
          if (isDeliverable && data['read'] != true) {
            unreadCount += 1;
          }
        }
        return unreadCount;
      }),
    ).asBroadcastStream();

    _unreadNotificationStreams[currentUserId] = stream;
    return stream;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('⚠️ Error marking notification read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipient_uid', isEqualTo: authUser.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error marking all notifications read: $e');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String projectId = '',
    DateTime? deliverAt,
    Map<String, dynamic>? data,
    bool dedupe = false,
    String? documentId,
  }) async {
    if (dedupe && type == 'chat_message') {
      final channelId = data?['channelId']?.toString() ?? '';
      if (channelId.isNotEmpty) {
        final existing = await _firestore
            .collection('notifications')
            .where('recipient_uid', isEqualTo: userId)
            .where('type', isEqualTo: 'chat_message')
            .where('id', isEqualTo: 'chat_message_${projectId}_$channelId')
            .where('read', isEqualTo: false)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          return;
        }
      }
    }

    final notificationRef = documentId == null
        ? _firestore.collection('notifications').doc()
        : _firestore.collection('notifications').doc(documentId);

    final payload = <String, dynamic>{
      'id': notificationRef.id,
      'userId': userId,
      'recipient_uid': userId,
      'projectId': projectId,
      'type': type,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'deliverAt': deliverAt != null ? Timestamp.fromDate(deliverAt) : null,
      'data': data ?? <String, dynamic>{},
      'dedupe': dedupe,
    };

    if (documentId != null) {
      final existing = await notificationRef.get();
      if (existing.exists) {
        await notificationRef.update(payload);
        return;
      }
    }

    await notificationRef.set(payload);
  }

  ProjectNotificationItem _parseNotificationItem(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProjectNotificationItem(
      id: doc.id,
      userId: data['recipient_uid'] as String? ?? data['userId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      type: data['type'] as String? ?? 'update',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: _parseDateTime(data['created_at']) ?? _parseDateTime(data['createdAt']) ?? DateTime.now(),
      deliverAt: _parseDateTime(data['deliverAt']),
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

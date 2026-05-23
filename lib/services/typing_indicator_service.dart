import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Typing indicator state for a user in a channel
class TypingIndicator {
  final String userId;
  final String username;
  final DateTime lastSeen;
  final Duration timeout; // How long until considered "not typing"

  TypingIndicator({
    required this.userId,
    required this.username,
    required this.lastSeen,
    this.timeout = const Duration(seconds: 3),
  });

  /// Check if user is still considered typing
  bool get isTyping {
    return DateTime.now().difference(lastSeen) < timeout;
  }

  factory TypingIndicator.fromMap(Map<String, dynamic> map) {
    return TypingIndicator(
      userId: map['userId'] as String? ?? '',
      username: map['username'] as String? ?? 'User',
      lastSeen: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'timestamp': Timestamp.fromDate(lastSeen),
    };
  }
}

/// Manages typing indicators for real-time collaboration
class TypingIndicatorService {
  TypingIndicatorService._();

  static final TypingIndicatorService instance = TypingIndicatorService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Debounce typing updates to reduce database writes
  final Map<String, Timer> _typingTimers = {};
  static const Duration _typingDebounce = Duration(milliseconds: 300);
  static const Duration _typingTimeout = Duration(seconds: 3);

  /// Signal that user is typing in a channel
  /// Returns immediately; uses debounce to avoid excessive writes
  void markTyping({
    required String projectId,
    required String channelId,
    required String userId,
    required String username,
  }) {
    // Cancel existing timer for this channel
    final timerId = '$projectId:$channelId';
    _typingTimers[timerId]?.cancel();

    // Update typing indicator with debounce
    _typingTimers[timerId] = Timer(_typingDebounce, () async {
      try {
        await _firestore
            .collection('projects')
            .doc(projectId)
            .collection('channels')
            .doc(channelId)
            .collection('typing')
            .doc(userId)
            .set(
              {
                'userId': userId,
                'username': username,
                'timestamp': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
      } catch (e) {
        print('⚠️ Error marking typing: $e');
      }
    });
  }

  /// Stop typing indicator for user
  Future<void> stopTyping({
    required String projectId,
    required String channelId,
    required String userId,
  }) async {
    final timerId = '$projectId:$channelId';
    _typingTimers[timerId]?.cancel();
    _typingTimers.remove(timerId);

    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('typing')
          .doc(userId)
          .delete();
    } catch (e) {
      print('⚠️ Error stopping typing: $e');
    }
  }

  /// Listen to typing indicators in a channel
  /// Filters out users whose timeout has expired
  Stream<List<TypingIndicator>> watchChannelTyping({
    required String projectId,
    required String channelId,
  }) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('typing')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => TypingIndicator.fromMap(doc.data()))
              .where((typing) {
                // Filter out expired typing indicators
                return now.difference(typing.lastSeen) < _typingTimeout;
              })
              .toList();
        });
  }

  /// Clean up typing indicator when app closes or user logs out
  Future<void> clearAllTypingIndicators(String userId) async {
    try {
      final projectSnapshots = await _firestore.collection('projects').get();
      
      for (final projectDoc in projectSnapshots.docs) {
        final channelSnapshots = await projectDoc.reference
            .collection('channels')
            .get();
        
        for (final channelDoc in channelSnapshots.docs) {
          await channelDoc.reference
              .collection('typing')
              .doc(userId)
              .delete()
              .catchError((e) {
                // Ignore if document doesn't exist
              });
        }
      }
    } catch (e) {
      print('⚠️ Error clearing typing indicators: $e');
    }
  }

  @override
  void dispose() {
    for (var timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
  }
}

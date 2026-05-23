import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:team_sync/services/call_service.dart';

/// Call notification statuses
enum CallNotificationStatus {
  pending,
  acknowledged,
  dismissed,
  expired
}

/// Represents a call notification/reminder
class CallNotification {
  final String notificationId;
  final String callId;
  final String projectId;
  final String callInitiatorName;
  final DateTime callScheduledAt;
  final DateTime createdAt;
  final CallNotificationStatus status;
  final bool isReminder; // true for reminder, false for incoming call

  CallNotification({
    required this.notificationId,
    required this.callId,
    required this.projectId,
    required this.callInitiatorName,
    required this.callScheduledAt,
    required this.createdAt,
    this.status = CallNotificationStatus.pending,
    this.isReminder = false,
  });

  factory CallNotification.fromFirestore(
    Map<String, dynamic> data,
    String notificationId,
  ) {
    return CallNotification(
      notificationId: notificationId,
      callId: data['callId'] ?? '',
      projectId: data['projectId'] ?? '',
      callInitiatorName: data['callInitiatorName'] ?? '',
      callScheduledAt: (data['callScheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: CallNotificationStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallNotificationStatus.pending,
      ),
      isReminder: data['isReminder'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'callId': callId,
    'projectId': projectId,
    'callInitiatorName': callInitiatorName,
    'callScheduledAt': Timestamp.fromDate(callScheduledAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status.name,
    'isReminder': isReminder,
  };

  CallNotification copyWith({
    String? notificationId,
    String? callId,
    String? projectId,
    String? callInitiatorName,
    DateTime? callScheduledAt,
    DateTime? createdAt,
    CallNotificationStatus? status,
    bool? isReminder,
  }) {
    return CallNotification(
      notificationId: notificationId ?? this.notificationId,
      callId: callId ?? this.callId,
      projectId: projectId ?? this.projectId,
      callInitiatorName: callInitiatorName ?? this.callInitiatorName,
      callScheduledAt: callScheduledAt ?? this.callScheduledAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isReminder: isReminder ?? this.isReminder,
    );
  }
}

/// Manages call notifications and reminders
class CallNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a call reminder notification (e.g., 30 mins before call)
  Future<void> createCallReminder({
    required String callId,
    required String projectId,
    required String initiatorName,
    required DateTime callScheduledAt,
    required List<String> participantIds,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in participantIds) {
        final notifRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('callNotifications')
            .doc();

        batch.set(notifRef, {
          'callId': callId,
          'projectId': projectId,
          'callInitiatorName': initiatorName,
          'callScheduledAt': Timestamp.fromDate(callScheduledAt),
          'createdAt': Timestamp.now(),
          'status': CallNotificationStatus.pending.name,
          'isReminder': true,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error creating call reminders: $e');
    }
  }

  /// Create incoming call notification (when call is started)
  Future<void> createIncomingCallNotification({
    required String callId,
    required String projectId,
    required String initiatorName,
    required DateTime callScheduledAt,
    required List<String> participantIds,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in participantIds) {
        final notifRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('callNotifications')
            .doc();

        batch.set(notifRef, {
          'callId': callId,
          'projectId': projectId,
          'callInitiatorName': initiatorName,
          'callScheduledAt': Timestamp.fromDate(callScheduledAt),
          'createdAt': Timestamp.now(),
          'status': CallNotificationStatus.pending.name,
          'isReminder': false,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error creating incoming call notifications: $e');
    }
  }

  /// Mark notification as acknowledged (user saw it)
  Future<void> acknowledgeNotification(
    String notificationId,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .doc(notificationId)
          .update({
        'status': CallNotificationStatus.acknowledged.name,
      });
    } catch (e) {
      throw Exception('Error acknowledging notification: $e');
    }
  }

  /// Mark notification as dismissed (user dismissed it)
  Future<void> dismissNotification(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .doc(notificationId)
          .update({
        'status': CallNotificationStatus.dismissed.name,
      });
    } catch (e) {
      throw Exception('Error dismissing notification: $e');
    }
  }

  /// Mark all pending notifications as dismissed or acknowledged
  Future<void> clearAllNotifications({bool dismissAll = false}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': dismissAll
              ? CallNotificationStatus.dismissed.name
              : CallNotificationStatus.acknowledged.name,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error clearing notifications: $e');
    }
  }

  /// Get pending call notifications (reminders and incoming calls)
  Future<List<CallNotification>> getPendingNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => CallNotification.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error getting pending notifications: $e');
    }
  }

  /// Watch pending notifications in real-time
  Stream<List<CallNotification>> watchPendingNotifications() {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CallNotification.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw Exception('Error watching pending notifications: $e');
    }
  }

  /// Count pending call notifications (for badge)
  Future<int> getPendingNotificationCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error getting pending notification count: $e');
    }
  }

  /// Watch pending notification count for badge updates
  Stream<int> watchPendingNotificationCount() {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      throw Exception('Error watching notification count: $e');
    }
  }

  /// Clean up expired call notifications (older than 24 hours)
  Future<void> cleanupExpiredNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final cutoffTime =
          Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1)));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('createdAt', isLessThan: cutoffTime)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error cleaning up expired notifications: $e');
    }
  }

  /// Get notification history (dismissed, acknowledged, expired)
  Future<List<CallNotification>> getNotificationHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status',
              whereIn: [
                CallNotificationStatus.dismissed.name,
                CallNotificationStatus.acknowledged.name,
                CallNotificationStatus.expired.name,
              ])
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => CallNotification.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error getting notification history: $e');
    }
  }

  /// Get incoming call notifications only (excluding reminders)
  Stream<List<CallNotification>> watchIncomingCalls() {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('callNotifications')
          .where('status', isEqualTo: CallNotificationStatus.pending.name)
          .where('isReminder', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CallNotification.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw Exception('Error watching incoming calls: $e');
    }
  }
}

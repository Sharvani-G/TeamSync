import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:team_sync/models/models.dart';
import 'package:team_sync/services/pagination_service.dart';

/// Call status enum for tracking call lifecycle
enum CallStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  missedCall
}

/// Represents a scheduled call or active call
class CallData {
  final String callId;
  final String projectId;
  final String initiatorId;
  final String initiatorName;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<String> participants;
  final List<String> activeParticipants;
  final CallStatus status;
  final String? roomId;
  final bool isScreen Sharing Active;
  final Map<String, dynamic> metadata;

  CallData({
    required this.callId,
    required this.projectId,
    required this.initiatorId,
    required this.initiatorName,
    required this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.participants = const [],
    this.activeParticipants = const [],
    this.status = CallStatus.scheduled,
    this.roomId,
    this.isScreenSharingActive = false,
    this.metadata = const {},
  });

  factory CallData.fromFirestore(Map<String, dynamic> data, String callId) {
    return CallData(
      callId: callId,
      projectId: data['projectId'] ?? '',
      initiatorId: data['initiatorId'] ?? '',
      initiatorName: data['initiatorName'] ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      participants: List<String>.from(data['participants'] ?? []),
      activeParticipants: List<String>.from(data['activeParticipants'] ?? []),
      status: CallStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CallStatus.scheduled,
      ),
      roomId: data['roomId'],
      isScreenSharingActive: data['isScreenSharingActive'] ?? false,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'projectId': projectId,
    'initiatorId': initiatorId,
    'initiatorName': initiatorName,
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
    'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    'participants': participants,
    'activeParticipants': activeParticipants,
    'status': status.name,
    'roomId': roomId,
    'isScreenSharingActive': isScreenSharingActive,
    'metadata': metadata,
  };

  CallData copyWith({
    String? callId,
    String? projectId,
    String? initiatorId,
    String? initiatorName,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    List<String>? participants,
    List<String>? activeParticipants,
    CallStatus? status,
    String? roomId,
    bool? isScreenSharingActive,
    Map<String, dynamic>? metadata,
  }) {
    return CallData(
      callId: callId ?? this.callId,
      projectId: projectId ?? this.projectId,
      initiatorId: initiatorId ?? this.initiatorId,
      initiatorName: initiatorName ?? this.initiatorName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      participants: participants ?? this.participants,
      activeParticipants: activeParticipants ?? this.activeParticipants,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      isScreenSharingActive: isScreenSharingActive ?? this.isScreenSharingActive,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Manages all call-related Firestore operations with pagination support
class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Schedule a new call for a project
  Future<String> scheduleCall({
    required String projectId,
    required DateTime scheduledAt,
    required List<String> participants,
    required String title,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userName = _auth.currentUser?.displayName ?? 'Unknown';

      final callRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc();

      await callRef.set({
        'projectId': projectId,
        'initiatorId': userId,
        'initiatorName': userName,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'participants': participants,
        'activeParticipants': [],
        'status': CallStatus.scheduled.name,
        'title': title,
        'createdAt': Timestamp.now(),
        'isScreenSharingActive': false,
        'metadata': {},
      });

      return callRef.id;
    } catch (e) {
      throw Exception('Error scheduling call: $e');
    }
  }

  /// Start an active call
  Future<void> startCall(String projectId, String callId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.inProgress.name,
        'startedAt': Timestamp.now(),
        'activeParticipants': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Error starting call: $e');
    }
  }

  /// Add participant to active call
  Future<void> addCallParticipant(
    String projectId,
    String callId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'activeParticipants': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Error adding call participant: $e');
    }
  }

  /// Remove participant from active call
  Future<void> removeCallParticipant(
    String projectId,
    String callId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'activeParticipants': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Error removing call participant: $e');
    }
  }

  /// End call and update status
  Future<void> endCall(String projectId, String callId) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.completed.name,
        'endedAt': Timestamp.now(),
        'activeParticipants': [],
      });
    } catch (e) {
      throw Exception('Error ending call: $e');
    }
  }

  /// Cancel a scheduled call
  Future<void> cancelCall(String projectId, String callId) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'status': CallStatus.cancelled.name,
      });
    } catch (e) {
      throw Exception('Error cancelling call: $e');
    }
  }

  /// Toggle screen sharing during active call
  Future<void> toggleScreenSharing(
    String projectId,
    String callId,
    bool isActive,
  ) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'isScreenSharingActive': isActive,
      });
    } catch (e) {
      throw Exception('Error toggling screen sharing: $e');
    }
  }

  /// Get first page of scheduled calls for project with pagination
  Future<PaginatedResults<CallData>> fetchScheduledCallsPage(
    String projectId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status', isEqualTo: CallStatus.scheduled.name)
          .orderBy('scheduledAt', descending: false)
          .limit(25)
          .get();

      final calls = snapshot.docs
          .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
          .toList();

      final hasMore = snapshot.docs.length >= 25;
      final nextCursor = hasMore
          ? PaginationCursor(
              lastDocument: snapshot.docs.last,
              hasMore: true,
              pageSize: 25,
            )
          : null;

      return PaginatedResults(
        items: calls,
        nextCursor: nextCursor,
        totalCount: calls.length,
      );
    } catch (e) {
      throw Exception('Error fetching scheduled calls: $e');
    }
  }

  /// Get paginated scheduled calls with cursor
  Future<PaginatedResults<CallData>> fetchScheduledCallsNextPage(
    String projectId,
    PaginationCursor cursor,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status', isEqualTo: CallStatus.scheduled.name)
          .orderBy('scheduledAt', descending: false)
          .startAfterDocument(cursor.lastDocument)
          .limit(cursor.pageSize)
          .get();

      final calls = snapshot.docs
          .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
          .toList();

      final hasMore = snapshot.docs.length >= cursor.pageSize;
      final nextCursor = hasMore
          ? PaginationCursor(
              lastDocument: snapshot.docs.last,
              hasMore: true,
              pageSize: cursor.pageSize,
            )
          : null;

      return PaginatedResults(
        items: calls,
        nextCursor: nextCursor,
        totalCount: calls.length,
      );
    } catch (e) {
      throw Exception('Error fetching next scheduled calls: $e');
    }
  }

  /// Get first page of call history with pagination
  Future<PaginatedResults<CallData>> fetchCallHistoryPage(
    String projectId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status',
              whereIn: [CallStatus.completed.name, CallStatus.missedCall.name])
          .orderBy('endedAt', descending: true)
          .limit(30)
          .get();

      final calls = snapshot.docs
          .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
          .toList();

      final hasMore = snapshot.docs.length >= 30;
      final nextCursor = hasMore
          ? PaginationCursor(
              lastDocument: snapshot.docs.last,
              hasMore: true,
              pageSize: 30,
            )
          : null;

      return PaginatedResults(
        items: calls,
        nextCursor: nextCursor,
        totalCount: calls.length,
      );
    } catch (e) {
      throw Exception('Error fetching call history: $e');
    }
  }

  /// Get paginated call history with cursor
  Future<PaginatedResults<CallData>> fetchCallHistoryNextPage(
    String projectId,
    PaginationCursor cursor,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status',
              whereIn: [CallStatus.completed.name, CallStatus.missedCall.name])
          .orderBy('endedAt', descending: true)
          .startAfterDocument(cursor.lastDocument)
          .limit(cursor.pageSize)
          .get();

      final calls = snapshot.docs
          .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
          .toList();

      final hasMore = snapshot.docs.length >= cursor.pageSize;
      final nextCursor = hasMore
          ? PaginationCursor(
              lastDocument: snapshot.docs.last,
              hasMore: true,
              pageSize: cursor.pageSize,
            )
          : null;

      return PaginatedResults(
        items: calls,
        nextCursor: nextCursor,
        totalCount: calls.length,
      );
    } catch (e) {
      throw Exception('Error fetching next call history: $e');
    }
  }

  /// Watch upcoming scheduled calls for real-time updates
  Stream<List<CallData>> watchUpcomingCalls(String projectId) {
    try {
      return _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status', isEqualTo: CallStatus.scheduled.name)
          .where('scheduledAt',
              isGreaterThan: Timestamp.now(),
              isLessThan: Timestamp.fromDate(
                DateTime.now().add(Duration(days: 7)),
              ))
          .orderBy('scheduledAt')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw Exception('Error watching upcoming calls: $e');
    }
  }

  /// Watch active calls in real-time
  Stream<List<CallData>> watchActiveCalls(String projectId) {
    try {
      return _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status', isEqualTo: CallStatus.inProgress.name)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CallData.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      throw Exception('Error watching active calls: $e');
    }
  }

  /// Get specific call details
  Future<CallData?> getCallDetails(String projectId, String callId) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .get();

      if (!doc.exists) return null;
      return CallData.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Error getting call details: $e');
    }
  }

  /// Check if user has any missed calls
  Future<int> getUnmissedCallCount(String projectId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .where('status', isEqualTo: CallStatus.missedCall.name)
          .where('participants', arrayContains: userId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error getting unmissed call count: $e');
    }
  }

  /// Update call metadata (e.g., recording URL, duration)
  Future<void> updateCallMetadata(
    String projectId,
    String callId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('calls')
          .doc(callId)
          .update({
        'metadata': FieldValue.mergeFields(metadata),
      });
    } catch (e) {
      throw Exception('Error updating call metadata: $e');
    }
  }
}

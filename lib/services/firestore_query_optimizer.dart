import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized Firestore query builder with index hints and best practices
class FirestoreQueryOptimizer {
  FirestoreQueryOptimizer._();

  static final FirestoreQueryOptimizer instance = FirestoreQueryOptimizer._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Build query for paginated projects list with index support
  /// Index required: (createdBy, createdAt), (collaborators.{uid}, createdAt)
  Query<Map<String, dynamic>> buildUserProjectsQuery({
    required String userId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore.collection('projects');

    // Composite index expected: (createdBy, createdAt DESC)
    query = query.where('createdBy', isEqualTo: userId);
    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1); // +1 to check if more exists

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for project collaborators - admin and regular
  /// Index required: (collaborators.{uid}, createdAt)
  Query<Map<String, dynamic>> buildUserCollaboratorProjectsQuery({
    required String userId,
    required String role, // 'admin' or 'collaborator'
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore.collection('projects');

    // Firestore map field queries require special handling
    final fieldPath = 'collaborators.$userId';
    query = query.where(fieldPath, isEqualTo: role);
    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for public projects discovery with pagination
  /// Index required: (visibility, createdAt DESC)
  Query<Map<String, dynamic>> buildPublicProjectsQuery({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collection('projects')
        .where('visibility', isEqualTo: 'public');

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for channel messages with pagination
  /// Index required: (createdAt DESC)
  Query<Map<String, dynamic>> buildChannelMessagesQuery({
    required String projectId,
    required String channelId,
    int limit = 30,
    Timestamp? beforeTime,
  }) {
    var query = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('messages');

    if (beforeTime != null) {
      query = query.where('createdAt', isLessThan: beforeTime);
    }

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    return query;
  }

  /// Build collection group query for searching messages across all channels
  /// Index required: Collection group messages (createdAt DESC)
  Query<Map<String, dynamic>> buildGlobalMessagesSearchQuery({
    required String searchText,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collectionGroup('messages')
        .where('text', isGreaterThanOrEqualTo: searchText)
        .where('text', isLessThan: '${searchText}z');

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for scheduled calls with pagination
  /// Index required: (projectId, scheduledAt DESC)
  Query<Map<String, dynamic>> buildScheduledCallsQuery({
    required String projectId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('calls')
        .where('status', isEqualTo: 'scheduled');

    query = query.orderBy('scheduledAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for call history
  /// Index required: (projectId, createdAt DESC)
  Query<Map<String, dynamic>> buildCallHistoryQuery({
    required String projectId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('calls')
        .where('status', whereIn: ['completed', 'cancelled']);

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for user transactions/payments
  /// Requires Firestore subcollection: users/{uid}/transactions
  /// Index: (status, createdAt DESC)
  Query<Map<String, dynamic>> buildTransactionHistoryQuery({
    required String userId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Build query for notifications with pagination
  /// Requires: users/{uid}/notifications
  /// Index: (type, createdAt DESC)
  Query<Map<String, dynamic>> buildNotificationsQuery({
    required String userId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');

    query = query.orderBy('createdAt', descending: true);
    query = query.limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  /// Firestore index requirements documentation
  static const String indexRequirementsDoc = '''
  ============================================
  REQUIRED FIRESTORE INDEXES FOR SCALABILITY
  ============================================

  1. Projects Collection:
     - Index: (createdBy, createdAt DESC)
       Purpose: User's created projects, paginated
     
     - Index: (collaborators.{uid}, createdAt DESC)
       Purpose: Projects where user is collaborator/admin, paginated
     
     - Index: (visibility, createdAt DESC)
       Purpose: Public projects discovery with pagination

  2. Channels > Messages Collection Group:
     - Index: (createdAt DESC)
       Purpose: Global message search and cross-channel queries
     
     - Enable Collection Group for: messages

  3. Projects > Calls Collection:
     - Index: (projectId, scheduledAt DESC)
       Purpose: Upcoming scheduled calls
     
     - Index: (projectId, createdAt DESC)
       Purpose: Call history with pagination

  4. Users > Transactions Subcollection:
     - Index: (createdAt DESC)
       Purpose: Payment history with pagination

  5. Users > Notifications Subcollection:
     - Index: (createdAt DESC)
       Purpose: Notification center pagination

  FIRESTORE RULES:
  - Add pagination rules to limit query costs
  - Implement data validation on write
  - Use security rules to prevent large unindexed queries

  PERFORMANCE MONITORING:
  - Monitor query latency in Firebase Console
  - Check for slow queries in Firestore Insights
  - Set budget alerts for read operations
  ''';
}

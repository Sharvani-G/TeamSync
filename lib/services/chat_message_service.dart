import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'project_service.dart';

/// Enhanced message operations service
class ChatMessageService {
  ChatMessageService._();

  static final ChatMessageService instance = ChatMessageService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProjectService _projectService = ProjectService.instance;

  /// Edit a message (only if sender and within 5 minutes)
  Future<void> editMessage({
    required String projectId,
    required String channelId,
    required String messageId,
    required String newText,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    if (newText.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    try {
      final messageRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final data = messageDoc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String? ?? '';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      // Verify sender
      if (senderId != authUser.uid) {
        throw Exception('You can only edit your own messages');
      }

      // Check if within edit window (5 minutes)
      final editWindow = Duration(minutes: 5);
      if (DateTime.now().difference(createdAt) > editWindow) {
        throw Exception('Message can only be edited within 5 minutes of sending');
      }

      // Update message
      await messageRef.update({
        'text': newText.trim(),
        'edited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error editing message: $e');
      rethrow;
    }
  }

  /// Delete a message (only if sender or admin)
  Future<void> deleteMessage({
    required String projectId,
    required String channelId,
    required String messageId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      final messageRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final data = messageDoc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String? ?? '';

      // Get project to check if user is admin
      final project = await _firestore
          .collection('projects')
          .doc(projectId)
          .get();
      
      final projectData = project.data() as Map<String, dynamic>?;
      final isProjectAdmin = projectData?['createdBy'] == authUser.uid ||
          projectData?['collaborators'][authUser.uid] == 'admin';

      // Verify sender or admin
      if (senderId != authUser.uid && !isProjectAdmin) {
        throw Exception('You can only delete your own messages');
      }

      // Soft delete: mark as deleted
      await messageRef.update({
        'deleted': true,
        'text': '[Message deleted]',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error deleting message: $e');
      rethrow;
    }
  }

  /// Pin a message to channel (admin only)
  Future<void> pinMessage({
    required String projectId,
    required String channelId,
    required String messageId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      // Verify user is admin
      final project = await _firestore
          .collection('projects')
          .doc(projectId)
          .get();
      
      final projectData = project.data() as Map<String, dynamic>?;
      final isProjectAdmin = projectData?['createdBy'] == authUser.uid ||
          projectData?['collaborators'][authUser.uid] == 'admin';

      if (!isProjectAdmin) {
        throw Exception('Only project admins can pin messages');
      }

      // Pin message by updating channel doc
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .update({
            'pinnedMessageId': messageId,
            'pinnedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('❌ Error pinning message: $e');
      rethrow;
    }
  }

  /// Unpin message from channel (admin only)
  Future<void> unpinMessage({
    required String projectId,
    required String channelId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      // Verify user is admin
      final project = await _firestore
          .collection('projects')
          .doc(projectId)
          .get();
      
      final projectData = project.data() as Map<String, dynamic>?;
      final isProjectAdmin = projectData?['createdBy'] == authUser.uid ||
          projectData?['collaborators'][authUser.uid] == 'admin';

      if (!isProjectAdmin) {
        throw Exception('Only project admins can unpin messages');
      }

      // Unpin message
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .update({
            'pinnedMessageId': FieldValue.delete(),
            'pinnedAt': FieldValue.delete(),
          });
    } catch (e) {
      print('❌ Error unpinning message: $e');
      rethrow;
    }
  }

  /// Search messages in a channel (full text)
  /// Note: Requires Firestore full-text search setup or manual implementation
  Future<List<ProjectChatMessage>> searchChannelMessages({
    required String projectId,
    required String channelId,
    required String query,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(300) // Search recent messages only
          .get();

      // Client-side search (Firestore doesn't support full-text search)
      final queryLower = query.toLowerCase();
      return snapshot.docs
          .where((doc) {
            final text = (doc.data()['text'] as String? ?? '')
                .toLowerCase();
            return text.contains(queryLower);
          })
          .map((doc) => _projectService._parseProjectChatMessage(doc))
          .toList();
    } catch (e) {
      print('❌ Error searching messages: $e');
      return [];
    }
  }

  /// Get message reply target (for quoted replies)
  Future<ProjectChatMessage?> getReplyTargetMessage({
    required String projectId,
    required String channelId,
    required String replyToMessageId,
  }) async {
    if (replyToMessageId.isEmpty) return null;

    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(replyToMessageId)
          .get();

      if (!doc.exists) return null;
      return _projectService._parseProjectChatMessage(doc);
    } catch (e) {
      print('⚠️ Error getting reply target: $e');
      return null;
    }
  }

  /// Get pinned message for a channel
  Future<ProjectChatMessage?> getPinnedMessage({
    required String projectId,
    required String channelId,
  }) async {
    try {
      final channelDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .get();

      final pinnedMessageId = channelDoc.data()?['pinnedMessageId'] as String?;
      if (pinnedMessageId == null || pinnedMessageId.isEmpty) {
        return null;
      }

      return getReplyTargetMessage(
        projectId: projectId,
        channelId: channelId,
        replyToMessageId: pinnedMessageId,
      );
    } catch (e) {
      print('⚠️ Error getting pinned message: $e');
      return null;
    }
  }

  /// Count unread messages in channel for user
  Future<int> getUnreadMessageCount({
    required String projectId,
    required String channelId,
    required String userId,
  }) async {
    try {
      final memberDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('members')
          .doc(userId)
          .get();

      final lastReadAt = (memberDoc.data()?['lastReadAt'] as Timestamp?)
          ?.toDate() ??
          DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastReadAt))
          .where('deleted', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('⚠️ Error counting unread: $e');
      return 0;
    }
  }

  /// Mark all messages as read in channel
  Future<void> markAllMessagesRead({
    required String projectId,
    required String channelId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('members')
          .doc(userId)
          .set({
            'lastReadAt': FieldValue.serverTimestamp(),
            'unreadCount': 0,
          }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Error marking messages read: $e');
    }
  }
}

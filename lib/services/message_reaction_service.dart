import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Emoji reactions supported in TeamSync
class MessageReaction {
  static const String thumbsUp = '👍';
  static const String thumbsDown = '👎';
  static const String heart = '❤️';
  static const String laugh = '😂';
  static const String wow = '😮';
  static const String thinking = '🤔';
  static const String rocket = '🚀';
  static const String fire = '🔥';

  static const List<String> allReactions = [
    thumbsUp,
    thumbsDown,
    heart,
    laugh,
    wow,
    thinking,
    rocket,
    fire,
  ];

  /// Get reaction display (with count and usernames)
  static String formatReactionDisplay(String emoji, List<String> usernames) {
    if (usernames.isEmpty) return '';
    if (usernames.length == 1) {
      return '$emoji ${usernames.first}';
    }
    return '$emoji ${usernames.length}';
  }
}

/// Service for managing message reactions
class MessageReactionService {
  MessageReactionService._();

  static final MessageReactionService instance = MessageReactionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a reaction to a message
  Future<void> addReaction({
    required String projectId,
    required String channelId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    if (!MessageReaction.allReactions.contains(emoji)) {
      throw Exception('Invalid emoji: $emoji');
    }

    try {
      // Add/update user ID in reactions array for this emoji
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({
            'reactions.$emoji': FieldValue.arrayUnion([userId]),
          });
    } catch (e) {
      print('❌ Error adding reaction: $e');
      rethrow;
    }
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String projectId,
    required String channelId,
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .update({
            'reactions.$emoji': FieldValue.arrayRemove([userId]),
          });
    } catch (e) {
      print('⚠️ Error removing reaction: $e');
      rethrow;
    }
  }

  /// Toggle a reaction (add if not present, remove if present)
  Future<void> toggleReaction({
    required String projectId,
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    try {
      // Fetch current message to check if user already reacted
      final messageDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final reactions = messageDoc.data()?['reactions'] as Map<String, dynamic>? ?? {};
      final userIds = (reactions[emoji] as List<dynamic>? ?? [])
          .cast<String>();

      if (userIds.contains(authUser.uid)) {
        // User already reacted, remove reaction
        await removeReaction(
          projectId: projectId,
          channelId: channelId,
          messageId: messageId,
          emoji: emoji,
          userId: authUser.uid,
        );
      } else {
        // User hasn't reacted, add reaction
        await addReaction(
          projectId: projectId,
          channelId: channelId,
          messageId: messageId,
          emoji: emoji,
          userId: authUser.uid,
        );
      }
    } catch (e) {
      print('❌ Error toggling reaction: $e');
      rethrow;
    }
  }

  /// Get all reactions for a message
  Future<Map<String, List<String>>> getMessageReactions({
    required String projectId,
    required String channelId,
    required String messageId,
  }) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .doc(messageId)
          .get();

      final reactions = doc.data()?['reactions'] as Map<String, dynamic>? ?? {};
      
      // Convert to proper map
      final result = <String, List<String>>{};
      reactions.forEach((emoji, userIds) {
        result[emoji] = List<String>.from(userIds as List? ?? []);
      });
      
      return result;
    } catch (e) {
      print('⚠️ Error getting reactions: $e');
      return {};
    }
  }

  /// Check if current user has reacted with specific emoji
  Future<bool> userHasReacted({
    required String projectId,
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) return false;

    try {
      final reactions = await getMessageReactions(
        projectId: projectId,
        channelId: channelId,
        messageId: messageId,
      );

      return reactions[emoji]?.contains(authUser.uid) ?? false;
    } catch (e) {
      print('⚠️ Error checking user reaction: $e');
      return false;
    }
  }
}

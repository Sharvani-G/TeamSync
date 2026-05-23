import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import './shared_widgets.dart';
import 'package:intl/intl.dart';

/// Enhanced message bubble with reactions, editing indicator, and reply display
class EnhancedMessageBubble extends StatelessWidget {
  final ProjectChatMessage message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReactionAdd;
  final Map<String, bool>? userReactions; // emoji -> hasUserReacted

  const EnhancedMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onReactionAdd,
    this.userReactions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Sender info row
        if (!isMe)
          Padding(
            padding: EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              message.senderUsername,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

        // Main message bubble
        GestureDetector(
          onLongPress: onReactionAdd,
          child: Container(
            constraints: BoxConstraints(maxWidth: 280),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? AppTheme.primary
                  : Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
              border: message.edited
                  ? Border.all(color: AppTheme.textMuted.withOpacity(0.3))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message text
                Text(
                  message.deleted ? '[Message deleted]' : message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    decorationLine: message.deleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),

                // Attachments (if any)
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 4,
                      children: message.attachments.map((attach) {
                        return AttachmentChip(
                          attachment: attach,
                          isMe: isMe,
                        );
                      }).toList(),
                    ),
                  ),

                // Time and edit indicator
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('H:mm').format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppTheme.textMuted,
                        ),
                      ),
                      if (message.edited)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            '(edited)',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : AppTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Message actions (edit, delete, reply on hover/long-press)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReply != null)
                GestureDetector(
                  onTap: onReply,
                  child: Icon(Icons.reply, size: 14, color: AppTheme.textMuted),
                ),
              if (onEdit != null)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
                  ),
                ),
              if (onDelete != null)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete,
                      size: 14,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Reactions row
        if (message.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              children: message.reactions.entries.map((entry) {
                final emoji = entry.key;
                final userIds = entry.value;
                final hasUserReacted = userReactions?[emoji] ?? false;

                return GestureDetector(
                  onTap: onReactionAdd,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasUserReacted
                          ? AppTheme.primary.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasUserReacted
                            ? AppTheme.primary.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '$emoji ${userIds.length}',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        SizedBox(height: 4),
      ],
    );
  }
}

/// Chip for displaying message attachment
class AttachmentChip extends StatelessWidget {
  final ProjectAttachment attachment;
  final bool isMe;

  const AttachmentChip({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  IconData get fileIcon {
    final type = attachment.mimeType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('image')) return Icons.image;
    if (type.contains('video')) return Icons.video_library;
    if (type.contains('audio')) return Icons.audio_file;
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : Color(0xFFE8EAED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fileIcon,
            size: 14,
            color: isMe ? Colors.white : AppTheme.primary,
          ),
          SizedBox(width: 4),
          Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isMe ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick reaction picker
class ReactionPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const ReactionPicker({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    const emojis = ['👍', '👎', '❤️', '😂', '😮', '🤔', '🚀', '🔥'];

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              onEmojiSelected(emoji);
              Navigator.pop(context);
            },
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Typing indicator animation
class TypingAnimation extends StatefulWidget {
  final String text;

  const TypingAnimation({super.key, this.text = 'typing'});

  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<TypingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dots = '.'.padRight(
          1 + (_controller.value * 3).toInt(),
        );
        return Text(
          '${widget.text}$dots',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: AppTheme.textMuted,
          ),
        );
      },
    );
  }
}

/// Pinned message banner for channel header
class PinnedMessageBanner extends StatelessWidget {
  final ProjectChatMessage message;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const PinnedMessageBanner({
    super.key,
    required this.message,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withOpacity(0.1),
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned message',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    message.deleted
                        ? '[Message deleted]'
                        : message.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Quoted reply preview in composer
class QuotedReplyPreview extends StatelessWidget {
  final ProjectChatMessage quotedMessage;
  final VoidCallback? onRemove;

  const QuotedReplyPreview({
    super.key,
    required this.quotedMessage,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderLeft: BorderSide(color: AppTheme.primary, width: 3),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reply to ${quotedMessage.senderUsername}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  quotedMessage.deleted
                      ? '[Message deleted]'
                      : quotedMessage.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }
}

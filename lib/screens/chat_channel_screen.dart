import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;
import '../services/attachment_service.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ChatChannelScreen extends StatelessWidget {
  final String projectId;
  final String channelId;
  const ChatChannelScreen({super.key, required this.projectId, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: '${project.title} • Channel',
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ChatChannelView(projectId: projectId, channelId: channelId),
            ),
          ),
        );
      },
    );
  }
}

class ChatChannelView extends StatefulWidget {
  final String projectId;
  final String channelId;
  const ChatChannelView({super.key, required this.projectId, required this.channelId});

  @override
  State<ChatChannelView> createState() => _ChatChannelViewState();
}

class _ChatChannelViewState extends State<ChatChannelView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late FocusNode _messageFocusNode;
  picker.PlatformFile? _pendingFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  late Stream<List<ProjectChatMessage>> _messageStream;
  int _messageLimit = 50;

  @override
  void initState() {
    super.initState();
    _messageFocusNode = FocusNode();
    _initStream();
    _scrollController.addListener(_onScroll);
  }

  void _initStream() {
    _messageStream = ProjectService.instance.watchChannelMessages(
      widget.projectId,
      widget.channelId,
      limit: _messageLimit,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 100) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_messageLimit < 500) {
      setState(() {
        _messageLimit += 50;
        _initStream();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final double end = _scrollController.position.maxScrollExtent;
        if (animate) {
          _scrollController.animateTo(
            end,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(end);
        }
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await AttachmentService.instance.pickFiles(allowMultiple: false);
    if (result.isNotEmpty) {
      setState(() => _pendingFile = result.first);
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingFile == null) return;

    if (_pendingFile != null) {
      setState(() {
        _isUploading = true;
        _uploadError = null;
        _uploadProgress = 0.0;
      });

      try {
        await AttachmentService.instance.attachToChatChannel(
          projectId: widget.projectId,
          channelId: widget.channelId,
          text: text,
          files: [_pendingFile!],
          onProgress: (p, name) => setState(() => _uploadProgress = p),
        );
        setState(() {
          _pendingFile = null;
          _isUploading = false;
        });
        _controller.clear();
      } catch (e) {
        setState(() {
          _isUploading = false;
          _uploadError = 'Upload failed: $e';
        });
        return;
      }
    } else {
      await ProjectService.instance.sendChannelMessage(
        projectId: widget.projectId,
        channelId: widget.channelId,
        text: text,
      );
      _controller.clear();
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ProjectChatMessage>>(
            stream: _messageStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isNotEmpty && snapshot.connectionState != ConnectionState.waiting) {
                _scrollToBottom(animate: true);
              }

              if (messages.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No messages yet',
                  subtitle: 'Start the conversation by sending a message below.',
                );
              }

              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == FirebaseAuth.instance.currentUser?.uid;
                  return _MessageBubble(message: msg, isMe: isMe);
                },
              );
            },
          ),
        ),
        if (_pendingFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.dpInfoBg,
            child: Row(
              children: [
                const Icon(Icons.attach_file, color: AppTheme.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pendingFile!.name,
                    style: AppTheme.heading3.copyWith(fontSize: 13, color: AppTheme.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isUploading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(value: _uploadProgress, strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.inkSecondary),
                    onPressed: () => setState(() => _pendingFile = null),
                  ),
              ],
            ),
          ),
        if (_uploadError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.dpDangerBg,
            child: Text(
              _uploadError!,
              style: AppTheme.metadataText.copyWith(color: AppColors.dpDanger),
            ),
          ),
        _MessageInputBar(
          controller: _controller,
          focusNode: _messageFocusNode,
          onSend: _handleSend,
          onAttach: _pickFile,
          isUploading: _isUploading,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ProjectChatMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  String _formatTimestamp(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppTheme.accent : AppTheme.groundMuted;
    final textColor = isMe ? Colors.white : AppTheme.ink;
    final metaColor = isMe ? Colors.white.withOpacity(0.75) : AppTheme.inkSecondary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 3, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
            child: Text(
              isMe ? 'You' : message.senderUsername,
              style: AppTheme.labelText.copyWith(
                color: isMe ? AppTheme.accent : AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
              border: isMe
                  ? null
                  : Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0616191F),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.attachments.isNotEmpty) ...[
                  ...message.attachments.map((a) => _ChatFileCard(attachment: a, isMe: isMe)),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: AppTheme.bodySmall.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 3, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
            child: Text(
              _formatTimestamp(message.createdAt),
              style: AppTheme.metadataText.copyWith(color: metaColor, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatFileCard extends StatelessWidget {
  final ProjectAttachment attachment;
  final bool isMe;
  const _ChatFileCard({required this.attachment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: isMe ? null : Border.all(color: AppTheme.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isMe ? Colors.white : AppTheme.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.name,
                  style: AppTheme.heading3.copyWith(
                    color: isMe ? Colors.white : AppTheme.ink,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatActionButton(
                label: 'Open',
                icon: Icons.open_in_new,
                isMe: isMe,
                onTap: () => launchUrl(
                  Uri.parse(attachment.downloadUrl.trim()),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(width: 8),
              _ChatActionButton(
                label: 'Download',
                icon: Icons.download_outlined,
                isMe: isMe,
                onTap: () => launchUrl(
                  Uri.parse('${attachment.downloadUrl.trim()}?fl_attachment'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isMe;
  final VoidCallback onTap;

  const _ChatActionButton({
    required this.label,
    required this.icon,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : AppColors.dpInfoBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isMe ? Colors.white : AppTheme.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.labelText.copyWith(
                color: isMe ? Colors.white : AppTheme.accent,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool isUploading;

  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttach,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(top: BorderSide(color: AppTheme.rule, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppTheme.inkSecondary),
              tooltip: 'Attach file',
              onPressed: isUploading ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.ink),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.groundMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.rule),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.rule),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            if (isUploading)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  tooltip: 'Send message',
                  onPressed: onSend,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as picker;
import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatChannelScreen extends StatelessWidget {
  final String projectId;
  final String channelId;

  const ChatChannelScreen(
      {super.key, required this.projectId, required this.channelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, projectSnapshot) {
        final project = projectSnapshot.data;

        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        return Scaffold(
          appBar: SimpleAppBar(
            title: project.title,
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, '/project/$projectId/call'),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, '/project/$projectId/call'),
              ),
            ],
          ),
          body: ChatChannelView(projectId: projectId, channelId: channelId),
        );
      },
    );
  }
}

class ChatChannelView extends StatefulWidget {
  final String projectId;
  final String channelId;

  const ChatChannelView(
      {super.key, required this.projectId, required this.channelId});

  @override
  State<ChatChannelView> createState() => _ChatChannelViewState();
}

class _ChatChannelViewState extends State<ChatChannelView> {
  static const int _pageSize = 30;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ProjectChatMessage> _olderMessages = [];
  final List<picker.PlatformFile> _pendingAttachments = [];

  ProjectChatMessage? _replyTarget;
  ProjectChatMessage? _editingTarget;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _autoScroll = true;
  bool _isUploadingAttachments = false;
  double _uploadProgress = 0;
  String _uploadLabel = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectService.instance.markChannelRead(
          projectId: widget.projectId, channelId: widget.channelId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingOlder &&
        _hasMoreOlder) {
      _loadOlderMessages();
    }
    _autoScroll = _scrollController.position.extentAfter < 160;
  }

  Future<void> _loadOlderMessages() async {
    final oldest =
        _combinedMessages.isNotEmpty ? _combinedMessages.first.createdAt : null;
    if (oldest == null) {
      return;
    }

    setState(() => _isLoadingOlder = true);
    try {
      final older = await ProjectService.instance.loadOlderChannelMessages(
        widget.projectId,
        widget.channelId,
        limit: _pageSize,
        before: oldest,
      );

      if (!mounted) return;
      setState(() {
        final existingIds = _olderMessages.map((message) => message.id).toSet();
        for (final message in older) {
          if (!existingIds.contains(message.id)) {
            _olderMessages.insert(0, message);
          }
        }
        if (older.length < _pageSize) {
          _hasMoreOlder = false;
        }
        _isLoadingOlder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOlder = false);
    }
  }

  List<ProjectChatMessage> get _combinedMessages {
    final latest = _latestMessages;
    final all = [..._olderMessages, ...latest];
    final seen = <String>{};
    final unique = <ProjectChatMessage>[];
    for (final message in all) {
      if (seen.add(message.id)) {
        unique.add(message);
      }
    }
    return unique;
  }

  List<ProjectChatMessage> _latestMessages = [];

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) {
      return;
    }

    final replyId = _replyTarget?.id ?? '';

    try {
      if (_editingTarget == null) {
        if (_pendingAttachments.isNotEmpty) {
          setState(() {
            _isUploadingAttachments = true;
            _uploadProgress = 0;
            _uploadLabel = _pendingAttachments.first.name;
          });

          await AttachmentService.instance.attachToChatChannel(
            projectId: widget.projectId,
            channelId: widget.channelId,
            text: text,
            replyToMessageId: replyId,
            files: _pendingAttachments,
            onProgress: (progress, fileName) {
              if (!mounted) return;
              setState(() {
                _isUploadingAttachments = true;
                _uploadLabel = fileName;
                _uploadProgress = progress;
              });
            },
          );
        } else {
          final messageId = FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('channels')
              .doc(widget.channelId)
              .collection('messages')
              .doc()
              .id;
          await ProjectService.instance.sendChannelMessage(
            projectId: widget.projectId,
            channelId: widget.channelId,
            text: text,
            replyToMessageId: replyId,
            attachments: const [],
            messageId: messageId,
          );
        }
      } else {
        await ProjectService.instance.editChannelMessage(
          projectId: widget.projectId,
          channelId: widget.channelId,
          messageId: _editingTarget!.id,
          newText: text,
        );
      }

      _controller.clear();
      if (!mounted) return;
      setState(() {
        _replyTarget = null;
        _editingTarget = null;
        _pendingAttachments.clear();
        _isUploadingAttachments = false;
        _uploadProgress = 0;
        _uploadLabel = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAttachments = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _pickAttachments() async {
    if (_editingTarget != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Finish editing before adding attachments.')),
      );
      return;
    }

    try {
      final files =
          await AttachmentService.instance.pickFiles(allowMultiple: true);
      debugPrint('Chat attachment picker returned ${files.length} files');
      if (!mounted || files.isEmpty) {
        return;
      }

      setState(() {
        _pendingAttachments.addAll(files);
      });
      debugPrint(
          'Pending chat attachments now: ${_pendingAttachments.map((file) => file.name).join(', ')}');
    } catch (e, stackTrace) {
      debugPrint('Chat attachment picker failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Attachment picker failed: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _removePendingAttachment(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients || !_autoScroll) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  ProjectChatMessage? _findReplyTarget(String messageId) {
    for (final message in _combinedMessages) {
      if (message.id == messageId) {
        return message;
      }
    }
    return null;
  }

  Future<void> _showActions(ProjectChatMessage message) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final project =
        await ProjectService.instance.watchProject(widget.projectId).first;
    final isAdmin =
        currentUser != null && project?.isAdmin(currentUser.uid) == true;
    final isOwner = currentUser != null && currentUser.uid == message.senderId;
    final canModify = isAdmin || isOwner;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: message.deleted ? '' : message.text));
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyTarget = message);
                  FocusScope.of(context).requestFocus(FocusNode());
                },
              ),
              if (canModify)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _editingTarget = message;
                      _replyTarget = null;
                      _controller.text = message.text;
                      _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length));
                    });
                  },
                ),
              if (canModify)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ProjectService.instance.deleteChannelMessage(
                      projectId: widget.projectId,
                      channelId: widget.channelId,
                      messageId: message.id,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectChatMessage>>(
      stream: ProjectService.instance.watchChannelMessages(
        widget.projectId,
        widget.channelId,
        limit: _pageSize,
      ),
      builder: (context, snapshot) {
        _latestMessages = snapshot.data ?? [];
        final messages = _combinedMessages;

        if (snapshot.connectionState == ConnectionState.waiting &&
            messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 170),
                child: messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        subtitle: 'Start the conversation in this channel',
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels <= 100 &&
                              !_isLoadingOlder &&
                              _hasMoreOlder) {
                            _loadOlderMessages();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          itemCount:
                              messages.length + (_isLoadingOlder ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (_isLoadingOlder && index == 0) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            final offset = _isLoadingOlder ? 1 : 0;
                            final message = messages[index - offset];
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            final isMe = currentUser != null &&
                                currentUser.uid == message.senderId;
                            final replyTarget = message.hasReply
                                ? _findReplyTarget(message.replyToMessageId)
                                : null;

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPress: () => _showActions(message),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 520),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe ? AppTheme.primary : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          Radius.circular(isMe ? 16 : 4),
                                      bottomRight:
                                          Radius.circular(isMe ? 4 : 16),
                                    ),
                                    border: Border.all(
                                        color: isMe
                                            ? AppTheme.primary
                                            : AppTheme.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          UserAvatar(
                                            name: message.senderUsername,
                                            username: message.senderUsername,
                                            size: 30,
                                            imageUrl: message.senderPhoto,
                                            color: isMe ? Colors.white : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message.senderUsername,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isMe
                                                        ? Colors.white
                                                        : AppTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatTimestamp(
                                                      message.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : AppTheme.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (message.edited)
                                            Text(
                                              'edited',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : AppTheme.textMuted),
                                            ),
                                        ],
                                      ),
                                      if (replyTarget != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? Colors.white.withOpacity(0.12)
                                                : const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border(
                                                left: BorderSide(
                                                    color: isMe
                                                        ? Colors.white
                                                        : AppTheme.primary,
                                                    width: 3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                replyTarget.senderUsername,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMe
                                                      ? Colors.white
                                                      : AppTheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                replyTarget.deleted
                                                    ? 'Message deleted'
                                                    : replyTarget.text,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      // If there are attachments, show them as file tiles/thumbnails
                                      if (message.attachments.isEmpty) ...[
                                        Text(
                                          message.deleted
                                              ? 'This message was deleted'
                                              : message.text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.45,
                                            fontStyle: message.deleted
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: message.deleted
                                                ? (isMe
                                                    ? Colors.white70
                                                    : AppTheme.textMuted)
                                                : (isMe
                                                    ? Colors.white
                                                    : AppTheme.textSecondary),
                                          ),
                                        ),
                                      ] else ...[
                                        if (message.text.isNotEmpty)
                                          Text(
                                            message.text,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isMe
                                                  ? Colors.white70
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                      ],
                                      if (message.attachments.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: message.attachments
                                              .map((attachment) {
                                            final sizeLabel = _formatFileSize(attachment.fileSize);
                                            return InkWell(
                                              onTap: () => launchUrl(
                                                Uri.parse(attachment.fileUrl),
                                                mode: LaunchMode.externalApplication,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isMe
                                                      ? Colors.white
                                                          .withOpacity(0.12)
                                                      : const Color(0xFFF8FAFC),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isMe
                                                        ? Colors.white
                                                            .withOpacity(0.18)
                                                        : AppTheme.border,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _iconForAttachmentType(
                                                          attachment.fileType),
                                                      size: 16,
                                                      color: isMe
                                                          ? Colors.white
                                                          : AppTheme.primary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            attachment.fileName,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: isMe ? Colors.white : AppTheme.textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            sizeLabel,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: isMe ? Colors.white70 : AppTheme.textMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                      onPressed: () => launchUrl(
                                                        Uri.parse(attachment.fileUrl),
                                                        mode: LaunchMode.externalApplication,
                                                      ),
                                                      icon: Icon(
                                                        Icons.download_outlined,
                                                        size: 16,
                                                        color: isMe ? Colors.white : AppTheme.primary,
                                                      ),
                                                      tooltip: 'Download',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTarget != null || _editingTarget != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                _editingTarget != null
                                    ? Icons.edit_outlined
                                    : Icons.reply_outlined,
                                size: 18,
                                color: AppTheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _editingTarget != null
                                    ? 'Editing message'
                                    : 'Replying to ${_replyTarget?.senderUsername ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _replyTarget = null;
                                _editingTarget = null;
                                _pendingAttachments.clear();
                                if (_editingTarget == null) {
                                  _controller.clear();
                                }
                              }),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    if (_isUploadingAttachments)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _uploadLabel.isNotEmpty
                                  ? 'Uploading $_uploadLabel'
                                  : 'Uploading attachment...',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _uploadProgress),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pendingAttachments.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                    _pendingAttachments.length, (index) {
                                  final file = _pendingAttachments[index];
                                  return Chip(
                                    label: Text(file.name,
                                        overflow: TextOverflow.ellipsis),
                                    avatar: Icon(
                                        _iconForAttachmentType(
                                            file.name.split('.').last),
                                        size: 16),
                                    onDeleted: () =>
                                        _removePendingAttachment(index),
                                  );
                                }),
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: _pickAttachments,
                                icon: const Icon(Icons.attach_file,
                                    color: AppTheme.textSecondary, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pushNamed(context,
                                    '/project/${widget.projectId}/call'),
                                icon: const Icon(Icons.call_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      minHeight: 40, maxHeight: 140),
                                  child: TextField(
                                    controller: _controller,
                                    maxLines: 5,
                                    minLines: 1,
                                    textInputAction: TextInputAction.newline,
                                    decoration: InputDecoration(
                                      hintText: _editingTarget != null
                                          ? 'Edit message'
                                          : 'Message this project',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 12),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _controller,
                                builder: (_, value, __) {
                                  final active = value.text.trim().isNotEmpty ||
                                      _pendingAttachments.isNotEmpty;
                                  return SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: IconButton(
                                      tooltip: 'Send message',
                                      onPressed: active ? _sendMessage : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor: active
                                            ? AppTheme.primary
                                            : const Color(0xFFD1D5DB),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.send_rounded,
                                          color: Colors.white, size: 18),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day $hour12:$minute $period';
  }

  IconData _iconForAttachmentType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
        return Icons.description_outlined;
      case 'zip':
        return Icons.archive_outlined;
      default:
        return Icons.attach_file;
    }
  }

  String _formatFileSize(int size) {
    if (size <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

// Anti-pattern guard:
// - Do not reintroduce self-notification echoes.
// - Do not write placeholder file rows before Storage upload completes.
// - Do not create duplicate unread chat alerts per message.
// - Do not show blank attachment downloads or SVG previews in-place.
// - Do not leak local optimistic chat state into the visible timeline.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart' as picker;
import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/file_delivery_service.dart';
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
  List<ProjectChatMessage> _latestMessages = [];
  final List<picker.PlatformFile> _pendingAttachments = [];
  final Set<String> _notifiedMessageIds = <String>{};
  StreamSubscription<List<ProjectChatMessage>>? _messageSubscription;
  Timer? _presenceTimer;

  ProjectChatMessage? _replyTarget;
  ProjectChatMessage? _editingTarget;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _autoScroll = true;
  bool _isUploadingAttachments = false;
  double _uploadProgress = 0;
  String _uploadLabel = '';
  String _uploadError = '';
  Future<void> Function()? _retryUploadAction;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _messageSubscription = ProjectService.instance
        .watchChannelMessages(
      widget.projectId,
      widget.channelId,
      limit: _pageSize,
    )
        .listen((messages) {
      if (messages.isEmpty) {
        return;
      }

      final latestMessage = messages.first;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null ||
          latestMessage.senderId.isEmpty ||
          latestMessage.senderId == currentUserId ||
          !_notifiedMessageIds.add(latestMessage.id)) {
        return;
      }

      _triggerIncomingNotificationUi(latestMessage);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectService.instance.markChannelRead(
          projectId: widget.projectId, channelId: widget.channelId);
    });

    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      FirebaseFirestore.instance
          .collection('presence')
          .doc(widget.projectId)
          .collection('channels')
          .doc(widget.channelId)
          .collection('users')
          .doc(uid)
          .set({
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageSubscription?.cancel();
    _presenceTimer?.cancel();
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

  List<ProjectChatMessage> get _combinedMessages => [
        ..._olderMessages,
        ..._latestMessages,
      ];

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
        before: oldest,
        limit: _pageSize,
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

  Future<void> _pickAttachments() async {
    if (_isUploadingAttachments) {
      return;
    }

    if (_editingTarget != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Finish editing before adding attachments.')),
      );
      return;
    }

    try {
      final files = await AttachmentService.instance.pickFiles(allowMultiple: true);
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

  Future<void> _sendMessage() async {
    if (_isUploadingAttachments) {
      return;
    }

    final text = _controller.text.trim();
    final attachments = List<picker.PlatformFile>.from(_pendingAttachments);
    final replyTarget = _replyTarget;
    final editingTarget = _editingTarget;

    if (text.isEmpty && attachments.isEmpty) {
      return;
    }

    try {
      if (editingTarget != null) {
        if (attachments.isNotEmpty) {
          throw Exception('Editing a message with attachments is not supported');
        }

        await ProjectService.instance.editChannelMessage(
          projectId: widget.projectId,
          channelId: widget.channelId,
          messageId: editingTarget.id,
          newText: text,
        );
      } else if (attachments.isNotEmpty) {
        setState(() {
          _isUploadingAttachments = true;
          _uploadProgress = 0;
          _uploadLabel = '';
          _uploadError = '';
          _retryUploadAction = null;
        });

        await AttachmentService.instance.attachToChatChannel(
          projectId: widget.projectId,
          channelId: widget.channelId,
          text: text,
          files: attachments,
          replyToMessageId: replyTarget?.id ?? '',
          onProgress: (progress, fileName) {
            if (!mounted) return;
            setState(() {
              _isUploadingAttachments = true;
              _uploadProgress = progress;
              _uploadLabel = fileName;
            });
          },
        ).timeout(const Duration(minutes: 2));
      } else {
        await ProjectService.instance.sendChannelMessage(
          projectId: widget.projectId,
          channelId: widget.channelId,
          text: text,
          replyToMessageId: replyTarget?.id ?? '',
        );
      }

      if (!mounted) return;
      setState(() {
        _controller.clear();
        _pendingAttachments.clear();
        _replyTarget = null;
        _editingTarget = null;
        _isUploadingAttachments = false;
        _uploadProgress = 0;
        _uploadLabel = '';
        _uploadError = '';
        _retryUploadAction = null;
      });
      _scrollToBottom();
      await ProjectService.instance.markChannelRead(
        projectId: widget.projectId,
        channelId: widget.channelId,
      );
    } catch (e, stackTrace) {
      debugPrint('[SCREEN REJECTION INTERCEPTED] Details: $e');
      debugPrint('-> Forensics Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isUploadingAttachments = false;
        _uploadError = e.toString();
        _retryUploadAction = () => _sendMessage();
      });
    }
  }

  void _clearUploadFailure() {
    if (!mounted) return;
    setState(() {
      _pendingAttachments.clear();
      _isUploadingAttachments = false;
      _uploadProgress = 0;
      _uploadLabel = '';
      _uploadError = '';
      _retryUploadAction = null;
    });
  }

  Widget _buildUploadPanel() {
    if (_isUploadingAttachments) {
      final isSaving = _uploadProgress >= 1.0;
      final statusLabel = isSaving
          ? 'Saving ${_uploadLabel.isNotEmpty ? _uploadLabel : 'attachment'}...'
          : _uploadProgress < 0.3
              ? 'Preparing ${_uploadLabel.isNotEmpty ? _uploadLabel : 'attachment'}...'
              : 'Uploading ${_uploadLabel.isNotEmpty ? _uploadLabel : 'attachment'}...';

      return Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isSaving)
                  Text(
                    '${(_uploadProgress * 100).clamp(0, 99).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  )
                else
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isSaving)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _uploadProgress.clamp(0, 0.99)),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2563EB),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    if (_uploadError.isNotEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pause_circle_outline,
                size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _uploadError,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: _retryUploadAction,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: _clearUploadFailure,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _triggerIncomingNotificationUi(ProjectChatMessage latestMessage) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('New message from ${latestMessage.senderUsername}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ProjectService.instance.watchChannelSnapshot(
        widget.projectId,
        widget.channelId,
        limit: _pageSize,
      ),
      builder: (context, snapshot) {
        if (snapshot.data?.docs.any((doc) => doc.metadata.hasPendingWrites) ?? false) {
          return const SizedBox.shrink();
        }

        _latestMessages = snapshot.hasData
            ? ProjectService.instance.parseChannelMessagesSnapshot(snapshot.data!)
            : [];
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
                                child: IntrinsicWidth(
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 520),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppTheme.primary
                                          : Colors.white,
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
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            UserAvatar(
                                              name: message.senderUsername,
                                              username: message.senderUsername,
                                              size: 30,
                                              imageUrl: message.senderPhoto,
                                              color:
                                                  isMe ? Colors.white : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              fit: FlexFit.loose,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    message.senderUsername,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isMe
                                                          ? Colors.white
                                                          : AppTheme
                                                              .textPrimary,
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
                                                          : AppTheme
                                                              .textMuted,
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
                                                  ? Colors.white
                                                      .withOpacity(0.12)
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
                                              mainAxisSize: MainAxisSize.min,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : AppTheme
                                                            .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        _buildMessageBody(message, isMe),
                                      ],
                                    ),
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
                    _buildUploadPanel(),
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
                                final wasEditing = _editingTarget != null;
                                _replyTarget = null;
                                _editingTarget = null;
                                if (wasEditing) {
                                  _pendingAttachments.clear();
                                  _controller.clear();
                                }
                              }),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
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
                                      label: Text(
                                        file.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF1E293B)),
                                      ),
                                      avatar: Icon(
                                        _iconForAttachmentType(file.name.split('.').last),
                                        size: 16,
                                        color: const Color(0xFF1E293B),
                                      ),
                                      onDeleted: () => _removePendingAttachment(index),
                                    );
                                }),
                              ),
                            ),
                          Opacity(
                            opacity: _isUploadingAttachments ? 0.5 : 1,
                            child: IgnorePointer(
                              ignoring: _isUploadingAttachments,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onLongPress: () async {
                                      await AttachmentService.instance
                                          .diagnoseStorageConnection();
                                    },
                                    child: IconButton(
                                      onPressed: _pickAttachments,
                                      icon: const Icon(Icons.attach_file,
                                          color: AppTheme.textSecondary,
                                          size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pushNamed(context,
                                        '/project/${widget.projectId}/call'),
                                    icon: const Icon(Icons.call_outlined,
                                        color: AppTheme.textSecondary,
                                        size: 20),
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
                                        textInputAction:
                                            TextInputAction.newline,
                                        decoration: InputDecoration(
                                          hintText: _editingTarget != null
                                              ? 'Edit message'
                                              : 'Message this project',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 12),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _controller,
                                    builder: (_, value, __) {
                                      final active = !_isUploadingAttachments &&
                                          (value.text.trim().isNotEmpty ||
                                              _pendingAttachments.isNotEmpty);
                                      return SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: IconButton(
                                          tooltip: 'Send message',
                                          onPressed:
                                              active ? _sendMessage : null,
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
                            ),
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
      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
        return Icons.image_outlined;
      case 'pdf':
      case 'application/pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'application/msword':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return Icons.description_outlined;
      case 'zip':
      case 'application/zip':
        return Icons.archive_outlined;
      default:
        return Icons.attach_file;
    }
  }

  bool _isImageAttachment(ProjectAttachment attachment) {
    return _mimeOrExtension(attachment).startsWith('image/');
  }

  bool _isPdfAttachment(ProjectAttachment attachment) {
    final mimeOrExt = _mimeOrExtension(attachment);
    return mimeOrExt == 'application/pdf' ||
        _fileExtension(attachment).toLowerCase() == '.pdf';
  }

  bool _isOfficeAttachment(ProjectAttachment attachment) {
    final mimeOrExt = _mimeOrExtension(attachment);
    final extension = _fileExtension(attachment).toLowerCase();
    return mimeOrExt.contains('officedocument') ||
        mimeOrExt == 'application/msword' ||
        mimeOrExt == 'application/vnd.ms-excel' ||
        mimeOrExt == 'application/vnd.ms-powerpoint' ||
        extension == '.doc' ||
        extension == '.docx' ||
        extension == '.xls' ||
        extension == '.xlsx' ||
        extension == '.ppt' ||
        extension == '.pptx';
  }

  String _mimeOrExtension(ProjectAttachment attachment) {
    final mime = attachment.mimeType.trim().toLowerCase();
    if (mime.isNotEmpty) {
      return mime;
    }
    final ext = _fileExtension(attachment).toLowerCase();
    if (ext.isEmpty) {
      return '';
    }
    if (ext == '.pdf') return 'application/pdf';
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    if (ext == '.png') return 'image/png';
    if (ext == '.gif') return 'image/gif';
    if (ext == '.webp') return 'image/webp';
    if (ext == '.svg') return 'image/svg+xml';
    if (ext == '.txt') return 'text/plain';
    if (ext == '.csv') return 'text/csv';
    if (ext == '.zip') return 'application/zip';
    if (ext == '.doc') return 'application/msword';
    if (ext == '.docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (ext == '.xls') return 'application/vnd.ms-excel';
    if (ext == '.xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (ext == '.ppt') return 'application/vnd.ms-powerpoint';
    if (ext == '.pptx') return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    return ext;
  }



  bool _isCloudinaryUrl(String url) {
    return url.trim().startsWith('https://res.cloudinary.com');
  }

  String _cloudinaryDownloadUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.contains('?') ? '$trimmed&fl_attachment' : '$trimmed?fl_attachment';
  }

  String _fileExtension(ProjectAttachment attachment) {
    final name = attachment.name.trim();
    final url = attachment.downloadUrl.trim();
    final source = name.isNotEmpty ? name : url;
    final uri = Uri.tryParse(source);
    final path = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : source;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex).toLowerCase();
  }

  String _docsViewerUrl(String url) {
    return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}';
  }

  Future<void> _showAttachmentMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showImageLightbox(ProjectAttachment attachment) async {
    final url = attachment.downloadUrl.trim();
    if (!_isCloudinaryUrl(url)) {
      await _showAttachmentMessage('File unavailable. Please re-upload.');
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Unable to preview this image.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(ProjectAttachment attachment) async {
    final downloadUrl = attachment.downloadUrl.trim();
    if (!_isCloudinaryUrl(downloadUrl)) {
      await _showAttachmentMessage('File unavailable. Please re-upload.');
      return;
    }

    if (_isImageAttachment(attachment)) {
      await _showImageLightbox(attachment);
      return;
    }

    await launchUrl(
      Uri.parse(downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _downloadAttachment(ProjectAttachment attachment) async {
    final downloadUrl = attachment.downloadUrl.trim();
    if (!_isCloudinaryUrl(downloadUrl)) {
      await _showAttachmentMessage('File unavailable. Please re-upload.');
      return;
    }

    await FileDeliveryService.instance.downloadFromUrl(
      url: _cloudinaryDownloadUrl(downloadUrl),
      fileName: attachment.name.isNotEmpty ? attachment.name : 'download',
    );
  }

  Widget _buildMessageBody(ProjectChatMessage message, bool isMe) {
    final displayAttachments = message.attachments.isNotEmpty
        ? message.attachments
        : message.hasFileLink
            ? [
                ProjectAttachment(
                  id: message.id,
                  name: message.fileName.isNotEmpty
                      ? message.fileName
                      : 'Attachment',
                  mimeType: message.fileType.isNotEmpty
                      ? message.fileType
                      : 'application/octet-stream',
                  size: message.fileSize,
                  downloadUrl: message.downloadUrl.isNotEmpty
                      ? message.downloadUrl
                      : message.fileUrl,
                  uploadedBy: message.senderId,
                  createdAt: message.createdAt,
                  storagePath: '',
                )
              ]
            : const [];

    if (displayAttachments.isEmpty) {
      return Text(
        message.deleted ? 'This message was deleted' : message.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
          color: message.deleted
              ? (isMe ? Colors.white70 : AppTheme.textMuted)
              : (isMe ? Colors.white : AppTheme.textSecondary),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: displayAttachments
          .map((attachment) => _buildAttachmentCard(
                attachment: attachment,
                isMe: isMe,
              ))
          .toList(),
    );
  }

  Widget _buildAttachmentCard({
    required ProjectAttachment attachment,
    required bool isMe,
  }) {
    final downloadUrl = attachment.downloadUrl.trim();
    if (!_isCloudinaryUrl(downloadUrl)) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isMe ? Colors.white.withOpacity(0.18) : AppTheme.border),
          ),
          child: const Text(
            'File unavailable. Please re-upload.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB91C1C),
            ),
          ),
        ),
      );
    }

    final isImage = _isImageAttachment(attachment);
    final backgroundColor =
        isMe ? Colors.white.withOpacity(0.12) : const Color(0xFFF8FAFC);
    final borderColor = isMe ? Colors.white.withOpacity(0.18) : AppTheme.border;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: InkWell(
        onTap: () => _openAttachment(attachment),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _showImageLightbox(attachment),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        downloadUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withOpacity(0.14)
                        : AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.14)
                              : AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _iconForAttachmentType(attachment.fileType),
                          color: isMe ? Colors.white : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isMe ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFileSize(attachment.fileSize),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _openAttachment(attachment),
                                  icon: Icon(
                                    Icons.open_in_new,
                                    size: 15,
                                    color: isMe ? Colors.white : AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Open',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppTheme.primary,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _downloadAttachment(attachment),
                                  icon: Icon(
                                    Icons.download_outlined,
                                    size: 15,
                                    color: isMe ? Colors.white : AppTheme.primary,
                                  ),
                                  label: Text(
                                    'Download',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

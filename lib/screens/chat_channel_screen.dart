import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatChannelScreen extends StatefulWidget {
  final String projectId;
  final String channelId;

  const ChatChannelScreen({super.key, required this.projectId, required this.channelId});

  @override
  State<ChatChannelScreen> createState() => _ChatChannelScreenState();
}

class _ChatChannelScreenState extends State<ChatChannelScreen> {
  static const int _pageSize = 30;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ProjectChatMessage> _olderMessages = [];

  ProjectChatMessage? _replyTarget;
  ProjectChatMessage? _editingTarget;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectService.instance.markProjectChatRead(projectId: widget.projectId);
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
    if (_scrollController.position.pixels <= 100 && !_isLoadingOlder && _hasMoreOlder) {
      _loadOlderMessages();
    }
    _autoScroll = _scrollController.position.extentAfter < 160;
  }

  Future<void> _loadOlderMessages() async {
    final oldest = _combinedMessages.isNotEmpty ? _combinedMessages.first.createdAt : null;
    if (oldest == null) {
      return;
    }

    setState(() => _isLoadingOlder = true);
    try {
      final older = await ProjectService.instance.loadOlderProjectMessages(
        projectId: widget.projectId,
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
    if (text.isEmpty) {
      return;
    }

    final replyId = _replyTarget?.id ?? '';

    try {
      if (_editingTarget == null) {
        await ProjectService.instance.sendProjectMessage(
          projectId: widget.projectId,
          text: text,
          replyToMessageId: replyId,
        );
      } else {
        await ProjectService.instance.editProjectMessage(
          projectId: widget.projectId,
          messageId: _editingTarget!.id,
          text: text,
        );
      }

      _controller.clear();
      if (!mounted) return;
      setState(() {
        _replyTarget = null;
        _editingTarget = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), behavior: SnackBarBehavior.floating),
      );
    }
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
    final project = await ProjectService.instance.watchProject(widget.projectId).first;
    final isAdmin = currentUser != null && project?.isAdmin(currentUser.uid) == true;
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
                  Clipboard.setData(ClipboardData(text: message.deleted ? '' : message.text));
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
                      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                    });
                  },
                ),
              if (canModify)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ProjectService.instance.deleteProjectMessage(
                      projectId: widget.projectId,
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
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, projectSnapshot) {
        final project = projectSnapshot.data;

        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                onPressed: () => Navigator.pushNamed(context, '/project/${widget.projectId}/call'),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined),
                onPressed: () => Navigator.pushNamed(context, '/project/${widget.projectId}/call'),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ProjectChatMessage>>(
                  stream: ProjectService.instance.watchProjectMessages(widget.projectId, limit: _pageSize),
                  builder: (context, snapshot) {
                    _latestMessages = snapshot.data ?? [];
                    final messages = _combinedMessages;

                    if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (messages.isEmpty) {
                      return const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        subtitle: 'Start the conversation in this project room',
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels <= 100 && !_isLoadingOlder && _hasMoreOlder) {
                          _loadOlderMessages();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: messages.length + (_isLoadingOlder ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (_isLoadingOlder && index == 0) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }

                          final offset = _isLoadingOlder ? 1 : 0;
                          final message = messages[index - offset];
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final isMe = currentUser != null && currentUser.uid == message.senderId;
                          final replyTarget = message.hasReply ? _findReplyTarget(message.replyToMessageId) : null;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _showActions(message),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 520),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? AppTheme.primary : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: Border.all(color: isMe ? AppTheme.primary : AppTheme.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        UserAvatar(
                                          name: message.senderUsername,
                                          size: 30,
                                          imageUrl: message.senderPhoto,
                                          color: isMe ? Colors.white : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                message.senderUsername,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMe ? Colors.white : AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTimestamp(message.createdAt),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe ? Colors.white70 : AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (message.edited)
                                          Text(
                                            'edited',
                                            style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : AppTheme.textMuted),
                                          ),
                                      ],
                                    ),
                                    if (replyTarget != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.white.withOpacity(0.12) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border(left: BorderSide(color: isMe ? Colors.white : AppTheme.primary, width: 3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              replyTarget.senderUsername,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isMe ? Colors.white : AppTheme.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              replyTarget.deleted ? 'Message deleted' : replyTarget.text,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMe ? Colors.white70 : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      message.deleted ? 'This message was deleted' : message.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.45,
                                        fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
                                        color: message.deleted
                                            ? (isMe ? Colors.white70 : AppTheme.textMuted)
                                            : (isMe ? Colors.white : AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
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
                      Icon(_editingTarget != null ? Icons.edit_outlined : Icons.reply_outlined, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _editingTarget != null
                              ? 'Editing message'
                              : 'Replying to ${_replyTarget?.senderUsername ?? ''}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _replyTarget = null;
                          _editingTarget = null;
                          if (_editingTarget == null) {
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
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/project/${widget.projectId}/call'),
                      icon: const Icon(Icons.video_call_outlined, color: AppTheme.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: _editingTarget != null ? 'Edit message' : 'Message this project',
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (_, value, __) {
                        final active = value.text.trim().isNotEmpty;
                        return GestureDetector(
                          onTap: active ? _sendMessage : null,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: active ? AppTheme.primary : const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day $hour:$minute $period';
  }
}

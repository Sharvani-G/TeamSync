import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;
import '../services/attachment_service.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_colors.dart';

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
        if (project == null) return const Scaffold(backgroundColor: AppColors.kBgDeep, body: Center(child: CircularProgressIndicator()));

        return Scaffold(
          backgroundColor: AppColors.kBgDeep,
          appBar: AppBar(
            backgroundColor: AppColors.kBgDeep,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(project.title, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
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
      // Near top (reverse: false, so top is oldest)
      // Actually my reverse is false, so top is oldest.
      // If we scroll to top, we want to load more.
      _loadMore();
    }
  }

  void _loadMore() {
    if (_messageLimit < 500) { // Safety cap
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
                // Only scroll if we were already at bottom or just sent a message
                // For simplicity in this overhaul, we scroll to bottom on new data if reverse is false
                _scrollToBottom(animate: true);
              }

              return ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(16.w),
                itemCount: messages.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            color: AppColors.kBgElevated,
            child: Row(
              children: [
                Icon(Icons.insert_drive_file, color: AppColors.kAccentLight, size: 20.sp),
                SizedBox(width: 12.w),
                Expanded(child: Text(_pendingFile!.name, style: TextStyle(color: Colors.white, fontSize: 13.sp), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (_isUploading)
                  SizedBox(width: 24.w, height: 24.w, child: CircularProgressIndicator(value: _uploadProgress, strokeWidth: 2))
                else
                  IconButton(icon: Icon(Icons.close, size: 20.sp, color: Colors.white70), onPressed: () => setState(() => _pendingFile = null)),
              ],
            ),
          ),
        if (_uploadError != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            color: AppColors.kDanger.withOpacity(0.1),
            child: Text(_uploadError!, style: TextStyle(color: AppColors.kDanger, fontSize: 12.sp)),
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 4.h, left: isMe ? 0 : 4.w, right: isMe ? 4.w : 0),
            child: Text(
              isMe ? 'You' : message.senderUsername,
              style: TextStyle(color: isMe ? AppColors.kAccentLight : AppColors.kAccentBlue, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.w),
            constraints: BoxConstraints(maxWidth: 0.75.sw),
            decoration: BoxDecoration(
              color: isMe ? AppColors.kAccentBlue : AppColors.kBgElevated,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.attachments.isNotEmpty) ...[
                  ...message.attachments.map((a) => _ChatFileCard(attachment: a)),
                  if (message.text.isNotEmpty) SizedBox(height: 8.h),
                ],
                if (message.text.isNotEmpty)
                  Text(message.text, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp)),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _formatTimestamp(message.createdAt),
            style: TextStyle(color: AppColors.kTextSecond, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}

class _ChatFileCard extends StatelessWidget {
  final ProjectAttachment attachment;
  const _ChatFileCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(attachment.downloadUrl), mode: LaunchMode.externalApplication),
      child: Container(
        margin: EdgeInsets.only(bottom: 4.h),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.white70, size: 16.sp),
            SizedBox(width: 8.w),
            Flexible(child: Text(attachment.name, style: TextStyle(color: Colors.white, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis)),
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

  const _MessageInputBar({required this.controller, required this.focusNode, required this.onSend, required this.onAttach, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      color: AppColors.kBgDeep,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: AppColors.kTextPrimary.withOpacity(0.7)),
            onPressed: isUploading ? null : onAttach,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: AppColors.kTextHint),
                filled: true,
                fillColor: AppColors.kBgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          if (isUploading)
            Padding(padding: EdgeInsets.all(12.w), child: SizedBox(width: 20.w, height: 20.w, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: Icon(Icons.send, color: AppColors.kAccentBlue),
              onPressed: onSend,
            ),
        ],
      ),
    );
  }
}

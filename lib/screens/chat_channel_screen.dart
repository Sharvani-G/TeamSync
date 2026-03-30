import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatChannelScreen extends StatefulWidget {
  final String projectId;
  final String channelId;

  const ChatChannelScreen(
      {super.key, required this.projectId, required this.channelId});

  @override
  State<ChatChannelScreen> createState() => _ChatChannelScreenState();
}

class _ChatChannelScreenState extends State<ChatChannelScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_LocalMessage> _messages = [];

  ChatChannel? get _channel {
    try {
      return chatChannels.firstWhere((c) => c.id == widget.channelId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(_LocalMessage(text: text, time: _now())));
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _now() {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final p = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    if (channel == null) {
      return const Scaffold(
        appBar: SimpleAppBar(title: 'Channel Not Found'),
        body: EmptyState(
            icon: Icons.error_outline,
            title: 'Channel not found',
            subtitle: ''),
      );
    }

    final channelLabel = '#${channel.name.toLowerCase().replaceAll(' ', '-')}';

    return Scaffold(
      appBar: SimpleAppBar(
        title: '$channelLabel • 4 online',
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Starting channel call...'),
                    behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: channel.messages.isEmpty && _messages.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: 'No messages yet',
                    subtitle: 'Start the conversation in $channelLabel',
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...channel.messages.map((msg) => _MessageBubble(
                            username: msg.username,
                            message: msg.message,
                            timestamp: msg.timestamp,
                            isMe: msg.userId == '1',
                          )),
                      ..._messages.map((msg) => _MessageBubble(
                            username: 'Alex',
                            message: msg.text,
                            timestamp: msg.time,
                            isMe: true,
                          )),
                    ],
                  ),
          ),
          _MessageInput(
            controller: _controller,
            channelName: channel.name.toLowerCase(),
            onSend: _sendMessage,
            onAttach: () {},
          ),
        ],
      ),
    );
  }
}

class _LocalMessage {
  final String text;
  final String time;
  const _LocalMessage({required this.text, required this.time});
}

class _MessageBubble extends StatelessWidget {
  final String username;
  final String message;
  final String timestamp;
  final bool isMe;

  const _MessageBubble({
    required this.username,
    required this.message,
    required this.timestamp,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: username, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(width: 8),
                    Text(timestamp,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final String channelName;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _MessageInput({
    required this.controller,
    required this.channelName,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: onAttach,
            icon: const Icon(Icons.attach_file,
                color: AppTheme.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: 'Message #$channelName'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              final active = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: active ? onSend : null,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatHomeScreen extends StatelessWidget {
  final String projectId;
  const ChatHomeScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final project = projects.firstWhere((p) => p.id == projectId,
        orElse: () => projects.first);
    return Scaffold(
      appBar: SimpleAppBar(
        title: project.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Video call started'),
                    behavior: SnackBarBehavior.floating),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Voice call started'),
                    behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Channels'),
          ...chatChannels.map((channel) {
            final hasUnread = channel.messages.isNotEmpty;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              leading:
                  const Icon(Icons.tag, size: 18, color: AppTheme.textMuted),
              title: Text(
                channel.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  color:
                      hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
              trailing: hasUnread
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle),
                    )
                  : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () => Navigator.pushNamed(
                  context, '/project/$projectId/chat/${channel.id}'),
              hoverColor: const Color(0xFFF3F4F6),
            );
          }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectNotificationItem>>(
      stream: ProjectService.instance.watchMyNotifications(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Notifications'),
            actions: [
              if (notifications.any((item) => !item.read))
                TextButton(
                  onPressed: () => ProjectService.instance.markAllNotificationsRead(),
                  child: const Text('Mark all read'),
                ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'No notifications',
                      subtitle: 'You are all caught up!',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return InkWell(
                          onTap: () => ProjectService.instance.markNotificationRead(item.id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: item.read ? Colors.white : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: item.read ? AppTheme.border : const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: item.read ? const Color(0xFFE5E7EB) : AppTheme.primary.withOpacity(0.12),
                                  child: Icon(
                                    _iconForType(item.type),
                                    size: 18,
                                    color: item.read ? AppTheme.textSecondary : AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(item.createdAt),
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.body,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'call_started':
        return Icons.videocam_outlined;
      case 'collaborator_added':
      case 'collaborator_removed':
        return Icons.people_outline;
      case 'join_request_accepted':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_none;
    }
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day';
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Dummy notifications data
  final List<NotificationItem> notifications = [
    NotificationItem(
      id: '1',
      title: 'New message in #general',
      body: 'User sent: "Let\'s sync up tomorrow"',
      type: NotificationType.message,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      title: 'Project invitation',
      body: 'You have been invited to join "Design System Review"',
      type: NotificationType.invitation,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      title: 'Call reminder',
      body: 'Your scheduled call starts in 15 minutes',
      type: NotificationType.call,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: '4',
      title: 'Collaborator added',
      body: 'John joined "Mobile App Redesign" project',
      type: NotificationType.collaborator,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
  ];

  late List<NotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.from(notifications);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications',
                subtitle: 'You\'ll see notifications here when you get messages or invitations.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _markAsRead(notification),
                  onDismiss: () => _removeNotification(notification),
                );
              },
            ),
    );
  }

  void _markAsRead(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _removeNotification(NotificationItem notification) {
    setState(() {
      _notifications.remove(notification);
    });
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

enum NotificationType {
  message,
  invitation,
  call,
  collaborator,
  reminder,
  other;

  IconData get icon {
    return switch (this) {
      NotificationType.message => Icons.chat_bubble_outline,
      NotificationType.invitation => Icons.mail_outline,
      NotificationType.call => Icons.phone_in_talk_outlined,
      NotificationType.collaborator => Icons.person_add_outlined,
      NotificationType.reminder => Icons.alarm_outlined,
      NotificationType.other => Icons.notifications_outlined,
    };
  }

  Color get color {
    return switch (this) {
      NotificationType.message => const Color(0xFF3B82F6),
      NotificationType.invitation => const Color(0xFF8B5CF6),
      NotificationType.call => const Color(0xFF10B981),
      NotificationType.collaborator => const Color(0xFFF59E0B),
      NotificationType.reminder => const Color(0xFFF97316),
      NotificationType.other => AppTheme.primary,
    };
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppTheme.danger,
        ),
      ),
      child: Card(
        color: notification.isRead ? null : const Color(0xFFF0F9FF),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notification.type.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    notification.type.icon,
                    color: notification.type.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(notification.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}

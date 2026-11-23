import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_item_widget.dart';
import '../../widgets/shared_widgets.dart';
import '../../theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _showUnreadOnly = false;
  late final Stream<List<ProjectNotificationItem>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = NotificationService.instance.watchMyNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: SimpleAppBar(
        title: 'Notifications',
        showBack: false,
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.instance.markAllNotificationsRead();
            },
            child: Text(
              'Mark all read',
              style: AppTheme.bodyFont(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Chips
              Row(
                children: [
                  _buildFilterChip(
                    label: 'All',
                    selected: !_showUnreadOnly,
                    onTap: () => setState(() => _showUnreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Unread only',
                    selected: _showUnreadOnly,
                    onTap: () => setState(() => _showUnreadOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder<List<ProjectNotificationItem>>(
                  stream: _notificationsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load notifications',
                          style: AppTheme.bodyFont(color: AppTheme.danger),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = (snapshot.data ?? <ProjectNotificationItem>[])
                        .where((item) => !_showUnreadOnly || !item.read)
                        .toList();

                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications',
                        subtitle: 'You are all caught up! New updates from your teams will appear here.',
                      );
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return NotificationItemWidget(
                          item: item,
                          onTap: () async {
                            await NotificationService.instance.markNotificationRead(item.id);
                            if (!context.mounted) return;
                            final projectId = item.projectId;
                            if (projectId.isNotEmpty) {
                              if (item.type == 'call_started' ||
                                  item.type == 'incoming_call' ||
                                  item.type == 'webrtc:incoming-call' ||
                                  item.type == 'meeting_scheduled') {
                                Navigator.pushNamed(context, '/project/$projectId/workspace/calls');
                              } else if (item.type == 'join_request' || item.type == 'request_accepted') {
                                Navigator.pushNamed(
                                  context,
                                  '/project/$projectId/workspace',
                                  arguments: {'type': item.type, 'projectId': projectId},
                                );
                              } else {
                                Navigator.pushNamed(context, '/project/$projectId');
                              }
                            }
                          },
                          onDismissed: () async {
                            await NotificationService.instance.markNotificationRead(item.id);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.rule,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodyFont(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppTheme.inkSecondary,
          ),
        ),
      ),
    );
  }
}

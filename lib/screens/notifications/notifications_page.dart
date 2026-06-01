import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_item_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        backgroundColor: AppColors.kBgElevated,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: NotificationService.instance.markAllNotificationsRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    selected: !_showUnreadOnly,
                    label: const Text('All'),
                    onSelected: (_) => setState(() => _showUnreadOnly = false),
                  ),
                  FilterChip(
                    selected: _showUnreadOnly,
                    label: const Text('Unread only'),
                    onSelected: (_) => setState(() => _showUnreadOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ProjectNotificationItem>>(
                  stream: NotificationService.instance.watchMyNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load notifications',
                          style: TextStyle(color: Colors.white),
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
                      return const Center(
                        child: Text(
                          'Nothing here yet',
                          style: TextStyle(color: Colors.white70),
                        ),
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
                            if (projectId.isNotEmpty && (item.type == 'call_started' || item.type == 'meeting_scheduled')) {
                              Navigator.pushNamed(context, '/project/$projectId');
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
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/project_service.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(title: const Text('Transaction history')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<JoinRequest>>(
          stream: ProjectService.instance.watchMyJoinRequests(),
          builder: (context, joinSnapshot) {
            return StreamBuilder<List<ProjectNotificationItem>>(
              stream: NotificationService.instance.watchMyNotifications(),
              builder: (context, notificationSnapshot) {
                final entries = <_HistoryEntry>[];

                for (final request in joinSnapshot.data ?? const <JoinRequest>[]) {
                  entries.add(_HistoryEntry(
                    title: 'Join request ${request.status}',
                    subtitle: request.message,
                    timestamp: request.createdAt,
                    icon: request.status == 'approved'
                        ? Icons.check_circle_outline
                        : Icons.pending_actions_outlined,
                  ));
                }

                for (final item in notificationSnapshot.data ?? const <ProjectNotificationItem>[]) {
                  if (item.type == 'request_approved' ||
                      item.type == 'request_rejected' ||
                      item.type == 'meeting_scheduled') {
                    entries.add(_HistoryEntry(
                      title: item.title,
                      subtitle: item.body,
                      timestamp: item.createdAt,
                      icon: item.type == 'request_approved'
                          ? Icons.verified_outlined
                          : Icons.notifications_outlined,
                    ));
                  }
                }

                entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No activity yet', style: TextStyle(color: Colors.white70)),
                  );
                }

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      color: const Color(0xFF111827),
                      child: ListTile(
                        leading: Icon(entry.icon, color: const Color(0xFF60A5FA)),
                        title: Text(entry.title, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '${entry.subtitle}\n${DateFormat('MMM d, y • h:mm a').format(entry.timestamp)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;

  const _HistoryEntry({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
  });
}
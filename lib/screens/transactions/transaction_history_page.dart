import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/project_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Activity & History'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: StreamBuilder<List<JoinRequest>>(
            stream: ProjectService.instance.watchMyJoinRequests(),
            builder: (context, joinSnapshot) {
              return StreamBuilder<List<ProjectNotificationItem>>(
                stream: NotificationService.instance.watchMyNotifications(),
                builder: (context, notificationSnapshot) {
                  if (joinSnapshot.connectionState == ConnectionState.waiting &&
                      notificationSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = <_HistoryEntry>[];

                  for (final request in joinSnapshot.data ?? const <JoinRequest>[]) {
                    final isApproved = request.status == 'approved';
                    final isRejected = request.status == 'rejected';

                    entries.add(_HistoryEntry(
                      title: 'Join request ${request.status.toUpperCase()}',
                      subtitle: request.message.isNotEmpty ? request.message : 'Submitted collaboration request',
                      timestamp: request.createdAt,
                      statusBadge: request.status,
                      icon: isApproved
                          ? Icons.check_circle_outline_rounded
                          : (isRejected ? Icons.cancel_outlined : Icons.pending_outlined),
                      badgeColor: isApproved
                          ? AppTheme.accent
                          : (isRejected ? AppTheme.danger : const Color(0xFFF59E0B)),
                    ));
                  }

                  for (final item in notificationSnapshot.data ?? const <ProjectNotificationItem>[]) {
                    if (item.type == 'request_approved' ||
                        item.type == 'request_rejected' ||
                        item.type == 'meeting_scheduled' ||
                        item.type == 'join_request') {
                      final isApproved = item.type == 'request_approved';
                      final isRejected = item.type == 'request_rejected';

                      entries.add(_HistoryEntry(
                        title: item.title,
                        subtitle: item.body,
                        timestamp: item.createdAt,
                        statusBadge: isApproved ? 'APPROVED' : (isRejected ? 'REJECTED' : 'NOTIFICATION'),
                        icon: isApproved
                            ? Icons.verified_outlined
                            : (isRejected ? Icons.cancel_outlined : Icons.notifications_none_rounded),
                        badgeColor: isApproved
                            ? AppTheme.accent
                            : (isRejected ? AppTheme.danger : AppTheme.inkSecondary),
                      ));
                    }
                  }

                  entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  if (entries.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      subtitle: 'Submitted join requests, status changes, and meeting schedule logs will appear here.',
                    );
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.rule, width: 1),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: entry.badgeColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(entry.icon, color: entry.badgeColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          entry.title,
                                          style: AppTheme.bodyFont(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.ink,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: entry.badgeColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          entry.statusBadge.toUpperCase(),
                                          style: AppTheme.bodyFont(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: entry.badgeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.subtitle,
                                    style: AppTheme.bodyFont(
                                      fontSize: 13,
                                      color: AppTheme.inkSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('MMM d, y • h:mm a').format(entry.timestamp),
                                    style: AppTheme.bodyFont(
                                      fontSize: 11,
                                      color: AppTheme.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String statusBadge;
  final IconData icon;
  final Color badgeColor;

  const _HistoryEntry({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.statusBadge,
    required this.icon,
    required this.badgeColor,
  });
}

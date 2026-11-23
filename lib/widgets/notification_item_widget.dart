import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class NotificationItemWidget extends StatelessWidget {
  final ProjectNotificationItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const NotificationItemWidget({
    super.key,
    required this.item,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(item.type);
    final timestamp = DateFormat('MMM d • h:mm a').format(item.createdAt);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.dpDangerBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.dpDanger),
      ),
      confirmDismiss: (_) async {
        onDismissed?.call();
        return true;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.read ? AppTheme.panel : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
            border: Border.all(
              color: item.read ? AppTheme.rule : AppTheme.accent.withOpacity(0.35),
              width: AppTheme.borderHairline,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0616191F),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.read ? AppTheme.groundMuted : AppColors.dpInfoBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.read ? AppTheme.rule : AppTheme.accent.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: item.read ? AppTheme.inkSecondary : AppTheme.accent,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.heading3.copyWith(
                              fontSize: 14.5,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.inkSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timestamp,
                      style: AppTheme.metadataText.copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'request_approved':
      case 'join_request_approved':
        return Icons.verified_outlined;
      case 'request_rejected':
      case 'join_request_rejected':
        return Icons.cancel_outlined;
      case 'meeting_scheduled':
      case 'call_scheduled':
        return Icons.event_outlined;
      case 'call_started':
        return Icons.videocam_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}

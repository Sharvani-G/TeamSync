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
    final accent = item.read ? AppColors.kBgCard : AppTheme.primary;
    final timestamp = DateFormat('MMM d • h:mm a').format(item.createdAt);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.kDanger,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDismissed?.call();
        return true;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
      child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.read ? AppColors.kBgCard : AppColors.kBgElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      timestamp,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
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
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/app_notification.dart';

/// Fila del centro de notificaciones.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  final AppNotification notification;
  final VoidCallback? onTap;

  IconData get _icon => switch (notification.type) {
    AppNotificationType.newBooking => Icons.event_available_rounded,
    AppNotificationType.requestSent => Icons.outbox_rounded,
    AppNotificationType.accepted => Icons.check_circle_rounded,
    AppNotificationType.rejected => Icons.block_rounded,
    AppNotificationType.cancelled => Icons.event_busy_rounded,
    AppNotificationType.completed => Icons.task_alt_rounded,
    AppNotificationType.noShow => Icons.person_off_rounded,
    AppNotificationType.reminder => Icons.alarm_rounded,
    AppNotificationType.newOrder => Icons.shopping_bag_rounded,
    AppNotificationType.orderUpdate => Icons.local_shipping_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final unread = !notification.isRead;

    return Material(
      color: unread
          ? scheme.primary.withValues(alpha: 0.06)
          : palette.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: unread
                  ? scheme.primary.withValues(alpha: 0.24)
                  : palette.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                child: Icon(_icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleSmall?.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(left: Insets.sm),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRelative(notification.createdAt),
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                        fontSize: 10,
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
}

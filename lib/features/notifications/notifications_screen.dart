import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import 'widgets/notification_tile.dart';
import '../../core/widgets/bel_empty_state.dart';

/// Centro de notificaciones del usuario autenticado.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final notifications = app.myNotifications;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: context.texts.titleLarge),
        centerTitle: false,
      ),
      body: notifications.isEmpty
          ? const BelEmptyState(
              framed: false,
              icon: Icons.notifications_none_rounded,
              title: 'Sin notificaciones por ahora',
              message:
                  'Aquí llegarán tus pedidos, confirmaciones, recordatorios y '
                  'avisos de la plataforma.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.sm,
                Insets.page,
                Insets.x4l,
              ),
              itemCount: notifications.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Insets.xs),
                    child: Row(
                      children: [
                        Text(
                          '${notifications.length} avisos',
                          style: context.texts.bodySmall?.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (app.unreadNotifications > 0)
                          BelButton(
                            label: 'Marcar leídas',
                            variant: BelButtonVariant.ghost,
                            compact: true,
                            expand: false,
                            onPressed: app.markAllNotificationsRead,
                          ),
                      ],
                    ),
                  );
                }

                final notification = notifications[index - 1];
                return NotificationTile(
                  notification: notification,
                  onTap: () => app.markNotificationRead(notification.id),
                );
              },
            ),
    );
  }
}

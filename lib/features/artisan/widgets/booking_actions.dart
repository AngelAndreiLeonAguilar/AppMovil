import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/booking.dart';

/// Aplica un cambio de estado y avisa al usuario con un SnackBar.
Future<void> applyBookingStatus(
  BuildContext context,
  Booking booking,
  BookingStatus next,
) async {
  final app = AppScope.read(context);
  final error = await app.changeBookingStatus(booking.id, next);

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Reservación actualizada: ${next.label}.',
        ),
      ),
    );
}

/// Confirmación para acciones delicadas (cancelar, no-show, rechazar).
Future<bool> confirmBookingAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final scheme = context.colors;
  final palette = context.palette;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(title, style: dialogContext.texts.titleLarge),
      content: Text(message, style: dialogContext.texts.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Volver',
            style: TextStyle(color: palette.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? scheme.error : scheme.primary,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

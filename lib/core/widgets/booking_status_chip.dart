import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../../domain/booking.dart';

/// Etiqueta visual del estado de una reservación.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status, this.compact = false});

  final BookingStatus status;
  final bool compact;

  /// Color semántico coherente en toda la app.
  Color _color(BuildContext context) {
    final scheme = context.colors;
    return switch (status) {
      BookingStatus.requested => scheme.secondary,
      BookingStatus.accepted => scheme.primary,
      BookingStatus.completed => const Color(0xFF4E7A5A),
      BookingStatus.rejected => scheme.error,
      BookingStatus.cancelledByTourist => scheme.error,
      BookingStatus.cancelledByArtisan => scheme.error,
      BookingStatus.noShow => const Color(0xFF8A5A2B),
    };
  }

  IconData get _icon => switch (status) {
    BookingStatus.requested => Icons.hourglass_top_rounded,
    BookingStatus.accepted => Icons.check_circle_outline_rounded,
    BookingStatus.completed => Icons.task_alt_rounded,
    BookingStatus.rejected => Icons.block_rounded,
    BookingStatus.cancelledByTourist => Icons.person_off_outlined,
    BookingStatus.cancelledByArtisan => Icons.event_busy_rounded,
    BookingStatus.noShow => Icons.do_not_disturb_on_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Insets.sm : Insets.md,
        vertical: compact ? 3 : Insets.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 11 : 13, color: color),
          SizedBox(width: compact ? 4 : Insets.xs + 2),
          Text(
            status.label,
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontSize: compact ? 9.5 : 11,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

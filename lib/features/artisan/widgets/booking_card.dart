import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_button.dart';
import '../../../core/widgets/bel_surface.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../domain/booking.dart';
import 'booking_actions.dart';

/// Tarjeta de reservación usada en el panel y en la lista del artesano.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.showActions = true,
  });

  final Booking booking;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final actions = showActions ? _actions(context) : null;

    return BelSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.folio,
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.touristName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              BookingStatusChip(status: booking.status, compact: true),
            ],
          ),

          const SizedBox(height: Insets.sm),

          Text(
            booking.serviceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodyMedium?.copyWith(
              color: palette.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            '${formatLongDate(booking.date)} · ${booking.timeSlot}\n'
            '${booking.people} ${booking.people == 1 ? 'persona' : 'personas'} · '
            '${formatPrice(booking.totalAmount)}',
            style: context.texts.bodySmall?.copyWith(height: 1.5),
          ),

          if (booking.depositAmount > 0) ...[
            const SizedBox(height: Insets.xs),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 13,
                  color: palette.textFaint,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.depositStatus == DepositStatus.simulatedPaid
                        ? 'Anticipo ${formatPrice(booking.depositAmount)} · '
                              'se cobra en el taller (la app no cobra en línea)'
                        : 'Anticipo ${formatPrice(booking.depositAmount)} · '
                              '${booking.depositStatus.label}',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textFaint,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              '“${booking.notes}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: palette.textMuted,
              ),
            ),
          ],

          if (actions != null) ...[
            const SizedBox(height: Insets.md),
            actions,
          ],
        ],
      ),
    );
  }

  Widget? _actions(BuildContext context) {
    switch (booking.status) {
      case BookingStatus.requested:
        return Row(
          children: [
            Expanded(
              child: BelButton(
                label: 'Rechazar',
                variant: BelButtonVariant.outline,
                compact: true,
                onPressed: () => _reject(context),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: BelButton(
                label: 'Aceptar',
                icon: Icons.check_rounded,
                compact: true,
                onPressed: () =>
                    applyBookingStatus(context, booking, BookingStatus.accepted),
              ),
            ),
          ],
        );
      case BookingStatus.accepted:
        return Row(
          children: [
            Expanded(
              child: BelButton(
                label: 'No asistió',
                variant: BelButtonVariant.outline,
                compact: true,
                onPressed: () => _noShow(context),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: BelButton(
                label: 'Completar',
                icon: Icons.task_alt_rounded,
                compact: true,
                onPressed: () => applyBookingStatus(
                  context,
                  booking,
                  BookingStatus.completed,
                ),
              ),
            ),
          ],
        );
      case BookingStatus.rejected:
      case BookingStatus.completed:
      case BookingStatus.cancelledByTourist:
      case BookingStatus.cancelledByArtisan:
      case BookingStatus.noShow:
        return null;
    }
  }

  Future<void> _reject(BuildContext context) async {
    final confirmed = await confirmBookingAction(
      context,
      title: 'Rechazar solicitud',
      message:
          'Se avisará a ${booking.touristName} y se devolverá el anticipo '
          'completo (${formatPrice(booking.depositAmount)}).',
      confirmLabel: 'Rechazar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await applyBookingStatus(context, booking, BookingStatus.rejected);
  }

  Future<void> _noShow(BuildContext context) async {
    final confirmed = await confirmBookingAction(
      context,
      title: 'Registrar no-show',
      message:
          'El anticipo de ${formatPrice(booking.depositAmount)} se retiene. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Registrar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await applyBookingStatus(context, booking, BookingStatus.noShow);
  }
}

import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_links.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_button.dart';
import '../../../core/widgets/booking_status_chip.dart';
import '../../../domain/booking.dart';
import '../../../domain/booking_rules.dart';
import '../../../domain/finance.dart';
import '../../../domain/user.dart';

/// Hoja de detalle de una reservación: datos, dinero, historial y acciones.
Future<void> showBookingDetail(BuildContext context, Booking booking) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookingDetailSheet(booking: booking),
  );
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final role = app.user?.role ?? UserRole.tourist;
    final live = app.bookingById(booking.id) ?? booking;
    final actions = BookingRules.actionsFor(live, role);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          Insets.sm,
          Insets.page,
          Insets.x3l,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESERVACIÓN ${live.folio}',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(live.serviceTitle, style: context.texts.titleLarge),
                  ],
                ),
              ),
              BookingStatusChip(status: live.status),
            ],
          ),
          const SizedBox(height: Insets.lg),

          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: live.touristName,
            value: live.touristPhone,
          ),
          if (role == UserRole.artisan && live.touristPhone.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Row(
                children: [
                  Expanded(
                    child: BelButton(
                      label: 'WhatsApp',
                      icon: Icons.chat_rounded,
                      compact: true,
                      variant: BelButtonVariant.outline,
                      onPressed: () => ContactLinks.open(
                        context,
                        ContactLinks.whatsapp(
                          live.touristPhone,
                          message:
                              'Hola ${live.touristName}, le escribimos del '
                              'taller por su visita "${live.serviceTitle}" '
                              'del ${formatLongDate(live.date)} a las '
                              '${live.timeSlot}.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: BelButton(
                      label: 'Llamar',
                      icon: Icons.call_outlined,
                      compact: true,
                      variant: BelButtonVariant.outline,
                      onPressed: () => ContactLinks.open(
                        context,
                        ContactLinks.call(live.touristPhone),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _InfoRow(
            icon: Icons.event_rounded,
            label: formatLongDate(live.date),
            value:
                '${live.timeSlot} · ${live.people} '
                '${live.people == 1 ? 'persona' : 'personas'}',
          ),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: formatPrice(live.totalAmount),
            value: live.hasDeposit
                ? 'Anticipo ${formatPrice(live.depositAmount)} · '
                      '${live.depositStatus.label}'
                : 'Sin anticipo',
          ),
          if (live.hasDeposit)
            _InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Saldo en el taller',
              value: formatPrice(live.balance),
            ),
          if (live.refundAmount > 0)
            _InfoRow(
              icon: Icons.undo_rounded,
              label: 'Reembolso',
              value: formatPrice(live.refundAmount),
            ),
          if (live.notes != null && live.notes!.isNotEmpty)
            _InfoRow(
              icon: Icons.sticky_note_2_outlined,
              label: 'Nota del turista',
              value: live.notes!,
            ),

          if (role == UserRole.artisan &&
              live.status != BookingStatus.rejected) ...[
            const SizedBox(height: Insets.md),
            _VisitCommissionBox(booking: live),
          ],

          const SizedBox(height: Insets.lg),
          Text(
            'HISTORIAL',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: Insets.sm),
          for (final event in live.history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 7, color: palette.textFaint),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      event.status.label,
                      style: context.texts.bodySmall,
                    ),
                  ),
                  Text(
                    '${formatShortDate(event.at)} · ${formatRelative(event.at)}',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

          if (role == UserRole.tourist && live.status.isActive) ...[
            const SizedBox(height: Insets.sm),
            Text(
              BookingRules.cancellationPolicyFor(live),
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.4,
              ),
            ),
          ],

          if (actions.isNotEmpty) ...[
            const SizedBox(height: Insets.lg),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: BelButton(
                  label: _labelFor(action),
                  icon: _iconFor(action),
                  variant: _isPrimary(action)
                      ? BelButtonVariant.primary
                      : BelButtonVariant.outline,
                  compact: true,
                  onPressed: () => _run(context, live, action),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _isPrimary(BookingStatus status) =>
      status == BookingStatus.accepted || status == BookingStatus.completed;

  String _labelFor(BookingStatus status) => switch (status) {
    BookingStatus.accepted => 'Aceptar solicitud',
    BookingStatus.rejected => 'Rechazar solicitud',
    BookingStatus.completed => 'Marcar como completada',
    BookingStatus.noShow => 'Registrar que no asistió',
    BookingStatus.cancelledByTourist => 'Cancelar mi reserva',
    BookingStatus.cancelledByArtisan => 'Cancelar visita',
    BookingStatus.requested => 'Solicitar de nuevo',
  };

  IconData _iconFor(BookingStatus status) => switch (status) {
    BookingStatus.accepted => Icons.check_rounded,
    BookingStatus.rejected => Icons.block_rounded,
    BookingStatus.completed => Icons.task_alt_rounded,
    BookingStatus.noShow => Icons.person_off_outlined,
    BookingStatus.cancelledByTourist => Icons.delete_outline_rounded,
    BookingStatus.cancelledByArtisan => Icons.event_busy_rounded,
    BookingStatus.requested => Icons.send_rounded,
  };

  Future<void> _run(
    BuildContext context,
    Booking live,
    BookingStatus next,
  ) async {
    final destructive =
        next == BookingStatus.rejected ||
        next == BookingStatus.noShow ||
        next == BookingStatus.cancelledByArtisan ||
        next == BookingStatus.cancelledByTourist;

    if (destructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogContext.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(_labelFor(next), style: dialogContext.texts.titleLarge),
          content: Text(
            next == BookingStatus.cancelledByTourist
                ? BookingRules.cancellationPolicyFor(live)
                : 'Esta acción se registrará en el historial de la reservación.',
            style: dialogContext.texts.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Confirmar',
                style: TextStyle(color: context.colors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final error = await context.app.changeBookingStatus(live.id, next);
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Reservación actualizada: ${next.label}.')),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: palette.textMuted),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.texts.bodyMedium?.copyWith(fontSize: 13.5),
                ),
                if (value.isNotEmpty)
                  Text(
                    value,
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Desglose para el taller: comisión de Bel-Aaktun e ingreso neto de la visita.
class _VisitCommissionBox extends StatelessWidget {
  const _VisitCommissionBox({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final split = app.visitSplitFor(booking);
    final entry = app.ledgerEntryFor(LedgerSource.visit, booking.id);
    final isSample = booking.id.startsWith('bk-seed-');
    final voided = entry?.status == LedgerStatus.voided;
    final String status;
    if (isSample) {
      status = 'Reservación de ejemplo: no genera comisión real.';
    } else if (entry == null) {
      status = 'Estimado con la tasa vigente. Se fija al confirmar la visita.';
    } else {
      status = switch (entry.status) {
        LedgerStatus.pending =>
          'Se confirma cuando marques la visita como '
              'completada.',
        LedgerStatus.earned =>
          entry.isSettled
              ? 'Comisión pagada a Bel-Aaktun.'
              : 'Comisión pendiente de pagar a Bel-Aaktun.',
        LedgerStatus.voided => 'Visita no realizada: no genera comisión.',
      };
    }

    String money(int value) =>
        value < 0 ? '−${formatPrice(-value)}' : formatPrice(value);

    Widget row(String label, String value, {bool bold = false}) {
      final style = bold ? context.texts.titleSmall : context.texts.bodySmall;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      );
    }

    final noCommission = voided || isSample;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tu ingreso por esta visita', style: context.texts.titleSmall),
          const SizedBox(height: Insets.sm),
          row('Precio total de la experiencia', money(split.gross)),
          row(
            'Comisión Bel-Aaktun (${formatRate(split.rateBps)})',
            money(noCommission ? 0 : -split.commission),
          ),
          const Divider(height: Insets.lg),
          row(
            'Tu ingreso neto',
            money(voided ? 0 : (isSample ? split.gross : split.net)),
            bold: true,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            status,
            style: context.texts.bodySmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

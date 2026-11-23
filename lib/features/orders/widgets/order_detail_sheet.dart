import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_links.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_button.dart';
import '../../../domain/finance.dart';
import '../../../domain/order.dart';
import '../../../domain/user.dart';
import 'order_widgets.dart';

/// Muestra el detalle de un pedido con las acciones de cada rol.
Future<void> showOrderDetail(BuildContext context, Order order) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OrderDetailSheet(orderId: order.id, fallback: order),
  );
}

/// Pide al taller fecha, hora e indicaciones para la recogida.
Future<({DateTime at, String? note})?> askPickup(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final start = initial != null && initial.isAfter(now)
      ? initial
      : DateTime(now.year, now.month, now.day + 1, 11);
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 120)),
    helpText: '¿Qué día puede pasar el cliente?',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
    helpText: '¿A qué hora?',
  );
  if (time == null || !context.mounted) return null;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!at.isAfter(DateTime.now())) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Elige una fecha y hora futuras.')),
    );
    return null;
  }
  final noteController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Recogida en el taller'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(formatPickup(at), style: dialogContext.texts.titleMedium),
          const SizedBox(height: Insets.md),
          TextField(
            controller: noteController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Indicaciones (opcional)',
              hintText: 'Ej. Pregunta por Doña Elena en la entrada',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;
  final note = noteController.text.trim();
  return (at: at, note: note.isEmpty ? null : note);
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.orderId, required this.fallback});

  final String orderId;
  final Order fallback;

  Future<void> _run(
    BuildContext context,
    Order order,
    OrderAction action,
  ) async {
    final app = context.app;
    final messenger = ScaffoldMessenger.of(context);
    String? note;
    DateTime? pickupAt;
    String? pickupNote;

    // Al aceptar se propone de una vez la fecha de recogida; al marcar
    // listo, es obligatoria si aún no existe.
    final needsPickup =
        (action.next == OrderStatus.accepted ||
            action.next == OrderStatus.ready) &&
        order.pickupAt == null;
    if (needsPickup) {
      final pickup = await askPickup(context);
      if (pickup == null) {
        if (action.next == OrderStatus.ready) return;
      } else {
        pickupAt = pickup.at;
        pickupNote = pickup.note;
      }
    }
    if (action.destructive) {
      if (!context.mounted) return;
      final result = await _askReason(context, action);
      if (result == null) return;
      note = result.isEmpty ? null : result;
    }

    final error = await app.changeOrderStatus(
      order.id,
      action.next,
      note: note,
      pickupAt: pickupAt,
      pickupNote: pickupNote,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'Pedido actualizado: ${action.next.label}.'),
        ),
      );
  }

  Future<void> _reschedule(BuildContext context, Order order) async {
    final app = context.app;
    final messenger = ScaffoldMessenger.of(context);
    final pickup = await askPickup(context, initial: order.pickupAt);
    if (pickup == null) return;
    final error = await app.scheduleOrderPickup(
      order.id,
      pickup.at,
      note: pickup.note,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Recogida programada. Le avisamos al cliente.',
          ),
        ),
      );
  }

  Future<String?> _askReason(BuildContext context, OrderAction action) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${action.label}?'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(
              action.label,
              style: TextStyle(color: dialogContext.colors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final order = app.orderById(orderId) ?? fallback;
    final role = app.user?.role ?? UserRole.tourist;
    final actions = OrderRules.actionsFor(order, role);
    final isArtisan = role == UserRole.artisan;
    final artisan = app.artisanById(order.artisanId);
    final contactPhone = isArtisan
        ? order.buyerPhone
        : ((artisan?.whatsapp ?? '').isNotEmpty
              ? artisan!.whatsapp!
              : (artisan?.phone ?? ''));
    final canSchedule = OrderRules.canSchedulePickup(order, role);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          0,
          Insets.page,
          Insets.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PEDIDO ${order.folio}',
                        style: context.texts.labelSmall?.copyWith(
                          color: palette.textMuted,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArtisan
                            ? order.buyerName
                            : (artisan?.name ?? 'Taller'),
                        style: context.texts.titleLarge,
                      ),
                    ],
                  ),
                ),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              order.status.description,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Recogida
            _PickupCard(
              order: order,
              address: artisan?.address ?? artisan?.cave,
              isArtisan: isArtisan,
              onReschedule: canSchedule
                  ? () => _reschedule(context, order)
                  : null,
            ),
            const SizedBox(height: Insets.lg),

            // Piezas
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: BelArtwork(
                          imagePath: item.productImage,
                          variant: ArtworkVariant.craft,
                          seed: item.productId.hashCode,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: context.texts.titleSmall,
                          ),
                          Text(
                            '${item.quantity} × ${formatPrice(item.unitPrice)}',
                            style: context.texts.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatPrice(item.subtotal),
                      style: context.texts.titleSmall,
                    ),
                  ],
                ),
              ),
            const Divider(height: Insets.xl),
            Row(
              children: [
                Text('Total', style: context.texts.titleMedium),
                const Spacer(),
                Text(
                  formatPrice(order.total),
                  style: context.texts.titleLarge?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Pago en el taller al recoger. La app todavía no procesa '
              'pagos en línea.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
            if (isArtisan && order.status != OrderStatus.rejected) ...[
              const SizedBox(height: Insets.md),
              _CommissionBox(order: order),
            ],
            if (order.notes != null) ...[
              const SizedBox(height: Insets.md),
              _Line(
                icon: Icons.notes_rounded,
                title: 'Indicaciones del comprador',
                value: order.notes!,
              ),
            ],
            if (contactPhone.trim().isNotEmpty) ...[
              const SizedBox(height: Insets.md),
              Row(
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
                          contactPhone,
                          message: isArtisan
                              ? 'Hola ${order.buyerName}, le escribimos del '
                                    'taller por su pedido ${order.folio}.'
                              : 'Hola, les escribo por mi pedido '
                                    '${order.folio} (${order.title}).',
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
                        ContactLinks.call(contactPhone),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: Insets.lg),
              for (final action in actions) ...[
                BelButton(
                  label: action.label,
                  variant: action.destructive
                      ? BelButtonVariant.ghost
                      : BelButtonVariant.primary,
                  onPressed: () => _run(context, order, action),
                ),
                const SizedBox(height: Insets.sm),
              ],
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
            for (final event in order.history.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: Text(
                  '${formatRelative(event.at)} · ${event.note == 'Recogida programada' ? 'Recogida programada' : event.status.label}'
                  '${event.note == null || event.note == 'Recogida programada' ? '' : ' — ${event.note}'}',
                  style: context.texts.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.order,
    required this.address,
    required this.isArtisan,
    this.onReschedule,
  });

  final Order order;
  final String? address;
  final bool isArtisan;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pickup = order.pickupAt;
    final String headline;
    if (pickup != null && order.status.isOpen) {
      headline = formatPickup(pickup);
    } else if (order.status == OrderStatus.requested) {
      headline = isArtisan
          ? 'Acepta el pedido para proponer la recogida'
          : 'El taller te dirá cuándo recogerlo';
    } else if (order.status.isAcceptedByArtisan) {
      headline = isArtisan
          ? 'Define cuándo puede pasar el cliente'
          : 'El taller definirá la fecha de recogida';
    } else {
      headline = order.status.label;
    }

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, color: context.colors.primary),
              const SizedBox(width: Insets.sm),
              Text(
                'RECOGER EN EL TALLER',
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(headline, style: context.texts.titleMedium),
          if (order.pickupNote != null) ...[
            const SizedBox(height: 2),
            Text(order.pickupNote!, style: context.texts.bodySmall),
          ],
          if ((address ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              address!,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          if (onReschedule != null) ...[
            const SizedBox(height: Insets.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReschedule,
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: Text(
                  pickup == null ? 'Programar recogida' : 'Cambiar fecha',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.palette.textMuted),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleSmall),
              Text(
                value,
                style: context.texts.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Desglose para el taller: comisión de Bel-Aaktun e ingreso neto.
class _CommissionBox extends StatelessWidget {
  const _CommissionBox({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final split = app.saleSplitFor(order);
    final entry = app.ledgerEntryFor(LedgerSource.sale, order.id);
    final String status;
    if (entry == null) {
      status = 'Estimado con la tasa vigente. Se fija al aceptar el pedido.';
    } else {
      status = switch (entry.status) {
        LedgerStatus.pending => 'Se confirma cuando entregues el pedido.',
        LedgerStatus.earned =>
          entry.isSettled
              ? 'Comisión pagada a Bel-Aaktun.'
              : 'Comisión pendiente de pagar a Bel-Aaktun.',
        LedgerStatus.voided => 'Pedido cancelado: no genera comisión.',
      };
    }
    final voided = entry?.status == LedgerStatus.voided;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tu ingreso por este pedido', style: context.texts.titleSmall),
          const SizedBox(height: Insets.sm),
          _MoneyRow(label: 'Total que paga el cliente', value: split.gross),
          _MoneyRow(
            label: 'Comisión Bel-Aaktun (${formatRate(split.rateBps)})',
            value: voided ? 0 : -split.commission,
          ),
          const Divider(height: Insets.lg),
          _MoneyRow(
            label: 'Tu ingreso neto',
            value: voided ? 0 : split.net,
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.texts.titleSmall : context.texts.bodySmall;
    final text = value < 0 ? '−${formatPrice(-value)}' : formatPrice(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(text, style: style),
        ],
      ),
    );
  }
}

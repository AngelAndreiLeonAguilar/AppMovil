import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_surface.dart';
import '../../../domain/order.dart';
import '../../../core/widgets/bel_empty_state.dart';

/// "Sáb 22 nov · 16:30".
String formatPickup(DateTime at) {
  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final time =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  return '${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]} · $time';
}

/// Etiqueta del estado de un pedido.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = switch (status) {
      OrderStatus.requested => scheme.secondary,
      OrderStatus.accepted => scheme.primary,
      OrderStatus.preparing => const Color(0xFF8A5A2B),
      OrderStatus.ready => const Color(0xFF2F6F8F),
      OrderStatus.delivered => const Color(0xFF4E7A5A),
      OrderStatus.rejected ||
      OrderStatus.cancelledByBuyer ||
      OrderStatus.cancelledByArtisan => scheme.error,
    };
    final icon = switch (status) {
      OrderStatus.requested => Icons.hourglass_top_rounded,
      OrderStatus.accepted => Icons.check_circle_outline_rounded,
      OrderStatus.preparing => Icons.handyman_outlined,
      OrderStatus.ready => Icons.storefront_rounded,
      OrderStatus.delivered => Icons.task_alt_rounded,
      OrderStatus.rejected => Icons.block_rounded,
      OrderStatus.cancelledByBuyer ||
      OrderStatus.cancelledByArtisan => Icons.remove_shopping_cart_outlined,
    };

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
          Icon(icon, size: compact ? 11 : 13, color: color),
          SizedBox(width: compact ? 4 : Insets.xs + 2),
          Text(
            status.label,
            style: context.texts.labelSmall?.copyWith(
              color: color,
              fontSize: compact ? 9.5 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un pedido en las listas del turista y del taller.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showBuyer = false,
    this.artisanName,
  });

  final Order order;
  final VoidCallback onTap;

  /// En la vista del taller se muestra quién compra.
  final bool showBuyer;

  /// En la vista del turista, el taller donde recoge.
  final String? artisanName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pieces =
        '${order.pieceCount} ${order.pieceCount == 1 ? 'pieza' : 'piezas'}';
    final pickup = order.pickupAt;
    final showPickup = pickup != null && order.status.isAcceptedByArtisan;

    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: BelArtwork(
                    imagePath: order.coverImage,
                    variant: ArtworkVariant.craft,
                    seed: order.id.hashCode,
                  ),
                ),
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
                            showBuyer ? order.buyerName : order.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.titleSmall?.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                        OrderStatusChip(status: order.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showBuyer
                          ? '${order.title} · $pieces'
                          : '$pieces · ${artisanName ?? 'Recoger en el taller'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${order.folio} · ${formatRelative(order.createdAt)}',
                          style: context.texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatPrice(order.total),
                          style: context.texts.titleSmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showPickup || order.status == OrderStatus.requested) ...[
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs + 2,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    showPickup
                        ? Icons.event_available_rounded
                        : Icons.schedule_rounded,
                    size: 15,
                    color: palette.textMuted,
                  ),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      showPickup
                          ? 'Recoger: ${formatPickup(pickup)}'
                          : showBuyer
                          ? 'Esperando tu respuesta'
                          : 'Esperando que el taller lo acepte',
                      style: context.texts.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (order.status.isAcceptedByArtisan && showBuyer) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Falta definir la fecha de recogida',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mensaje vacío común de pedidos.
class EmptyOrders extends StatelessWidget {
  const EmptyOrders({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.xl,
        Insets.page,
        0,
      ),
      child: BelEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: title,
        message: message,
      ),
    );
  }
}

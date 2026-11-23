import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_stat_tile.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/booking_status_chip.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/booking.dart';
import '../booking/widgets/booking_detail_sheet.dart';
import '../notifications/widgets/notifications_bell.dart';
import 'widgets/profile_progress_card.dart';

/// Panel principal del artesano: contadores, dinero y actividad reciente.
class ArtisanDashboardScreen extends StatelessWidget {
  const ArtisanDashboardScreen({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final artisan = app.artisan;
    final palette = context.palette;
    final counters = app.counters;
    final now = DateTime.now();
    final month = app.financeSummary(since: DateTime(now.year, now.month));
    final allTime = app.financeSummary();
    final lowStock = app.lowStockProducts;
    final pending = app.pendingBookings;
    final recent = app.visibleBookings.take(4).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Panel del taller',
            title: artisan?.name ?? 'Mi taller',
            subtitle: artisan?.craft ?? 'Administra tus visitas y tus piezas.',
            actions: const [NotificationsBell()],
          ),
        ),

        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Insets.page,
              0,
              Insets.page,
              Insets.lg,
            ),
            child: ProfileProgressCard(),
          ),
        ),

        if (app.pendingOrdersCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                0,
                Insets.page,
                Insets.lg,
              ),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.md),
                elevated: true,
                onTap: () => onSelectTab(1),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        app.pendingOrdersCount == 1
                            ? 'Tienes 1 pedido de piezas por aceptar'
                            : 'Tienes ${app.pendingOrdersCount} pedidos de '
                                  'piezas por aceptar',
                        style: context.texts.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),

        if (AppConfig.showDemoBadges)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                0,
                Insets.page,
                Insets.lg,
              ),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: context.colors.secondary,
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        'Los anticipos de visitas son simulados: la app '
                        'todavía no cobra en línea.',
                        style: context.texts.bodySmall?.copyWith(
                          color: palette.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Contadores
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BelStatTile(
                        label: 'Por responder',
                        value: '${counters.pending}',
                        icon: Icons.hourglass_top_rounded,
                        accent: context.colors.secondary,
                        onTap: () => onSelectTab(1),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: BelStatTile(
                        label: 'Confirmadas',
                        value: '${counters.confirmed}',
                        icon: Icons.check_circle_outline_rounded,
                        onTap: () => onSelectTab(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  children: [
                    Expanded(
                      child: BelStatTile(
                        label: 'Próximas 7 días',
                        value: '${counters.upcoming}',
                        icon: Icons.event_available_rounded,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: BelStatTile(
                        label: 'Completadas',
                        value: '${counters.completed}',
                        icon: Icons.task_alt_rounded,
                        accent: const Color(0xFF4E7A5A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Dinero
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              0,
            ),
            child: BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              elevated: true,
              onTap: () => onSelectTab(3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'INGRESOS DE ESTE MES',
                        style: context.texts.labelSmall?.copyWith(
                          color: palette.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.textFaint,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      _MoneyColumn(
                        label: 'Tu ingreso neto',
                        value: month.artisanNetEarned,
                        color: context.colors.primary,
                      ),
                      _MoneyColumn(
                        label: 'Por confirmar',
                        value: allTime.artisanNetPending,
                        color: context.colors.secondary,
                      ),
                      _MoneyColumn(
                        label: 'Comisión por pagar',
                        value: allTime.commissionToSettle,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (lowStock.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.md,
                Insets.page,
                0,
              ),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.md),
                onTap: () => onSelectTab(2),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lowStock.length == 1
                                ? '1 pieza con pocas existencias'
                                : '${lowStock.length} piezas con pocas '
                                      'existencias',
                            style: context.texts.titleSmall,
                          ),
                          Text(
                            lowStock
                                .map(
                                  (product) =>
                                      '${product.name} (${product.stock})',
                                )
                                .join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),

        // Solicitudes por responder
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xl,
              Insets.page,
              Insets.sm,
            ),
            child: Row(
              children: [
                Text(
                  'SOLICITUDES POR RESPONDER',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                if (pending.length > 2)
                  BelButton(
                    label: 'Ver todas',
                    variant: BelButtonVariant.ghost,
                    compact: true,
                    expand: false,
                    onPressed: () => onSelectTab(1),
                  ),
              ],
            ),
          ),
        ),

        if (pending.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: BelSurface(
                padding: const EdgeInsets.all(Insets.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      color: context.colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'No hay solicitudes pendientes. Todo al día.',
                        style: context.texts.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Column(
                children: [
                  for (final booking in pending.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: _PendingRow(booking: booking),
                    ),
                ],
              ),
            ),
          ),

        // Actividad reciente
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xl,
              Insets.page,
              Insets.sm,
            ),
            child: Text(
              'ACTIVIDAD RECIENTE',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textMuted,
                letterSpacing: 2,
              ),
            ),
          ),
        ),

        SliverList.builder(
          itemCount: recent.length,
          itemBuilder: (context, index) {
            final booking = recent[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xs,
                Insets.page,
                Insets.xs,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => showBookingDetail(context, booking),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm,
                      vertical: Insets.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.touristName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.titleSmall?.copyWith(
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '${formatShortDate(booking.date)} · '
                                '${booking.timeSlot} · ${booking.serviceTitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: palette.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        BookingStatusChip(
                          status: booking.status,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

class _MoneyColumn extends StatelessWidget {
  const _MoneyColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPrice(value),
              style: context.texts.titleMedium?.copyWith(
                color: color,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BelSurface(
      onTap: () => showBookingDetail(context, booking),
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.touristName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatShortDate(booking.date)} · ${booking.timeSlot} · '
                  '${booking.people} ${booking.people == 1 ? 'persona' : 'personas'}',
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Icon(Icons.chevron_right_rounded, size: 18, color: palette.textFaint),
        ],
      ),
    );
  }
}

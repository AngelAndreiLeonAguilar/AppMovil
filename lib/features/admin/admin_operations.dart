import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/booking_status_chip.dart';
import '../../domain/booking.dart';
import '../../domain/finance.dart';
import '../../domain/order.dart';
import '../booking/widgets/booking_detail_sheet.dart';
import '../orders/widgets/order_detail_sheet.dart';
import '../orders/widgets/order_widgets.dart';

/// Resumen general de la plataforma.
class AdminOverviewPanel extends StatelessWidget {
  const AdminOverviewPanel({super.key, required this.users});

  /// Cuentas por rol (viene de la API de cuentas).
  final Map<String, int> users;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final stats = app.platformStats;
    final now = DateTime.now();
    final month = app.financeSummary(since: DateTime(now.year, now.month));

    final tiles = <_Tile>[
      _Tile(
        icon: Icons.payments_outlined,
        label: 'Ingreso Bel-Aaktun · este mes',
        value: formatPrice(month.commissionEarned),
        highlight: true,
      ),
      _Tile(
        icon: Icons.hourglass_top_rounded,
        label: 'Comisión por confirmar',
        value: formatPrice(month.commissionPending),
      ),
      _Tile(
        icon: Icons.luggage_outlined,
        label: 'Turistas',
        value: '${users['turista'] ?? 0}',
      ),
      _Tile(
        icon: Icons.storefront_outlined,
        label: 'Talleres publicados',
        value: '${stats.publishedArtisans}',
      ),
      _Tile(
        icon: Icons.inventory_2_outlined,
        label: 'Piezas publicadas',
        value: '${stats.activeProducts} de ${stats.totalProducts}',
      ),
      _Tile(
        icon: Icons.event_available_outlined,
        label: 'Experiencias activas',
        value: '${stats.activeServices} de ${stats.totalServices}',
      ),
      _Tile(
        icon: Icons.shopping_bag_outlined,
        label: 'Pedidos en curso',
        value: '${stats.ordersOpen}',
        detail: '${stats.ordersPendingAcceptance} sin aceptar',
      ),
      _Tile(
        icon: Icons.task_alt_rounded,
        label: 'Pedidos entregados',
        value: '${stats.ordersDelivered}',
        detail: '${stats.ordersCancelled} cancelados o rechazados',
      ),
      _Tile(
        icon: Icons.event_note_outlined,
        label: 'Reservaciones activas',
        value: '${stats.bookingsRequested + stats.bookingsConfirmed}',
        detail: '${stats.bookingsRequested} por responder',
      ),
      _Tile(
        icon: Icons.verified_outlined,
        label: 'Visitas realizadas',
        value: '${stats.bookingsCompleted}',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.md,
        Insets.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - Insets.sm) / 2;
              return Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final tile in tiles) SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Las reservaciones de ejemplo no se cuentan en estas cifras.',
            style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = highlight ? context.colors.onPrimary : palette.text;
    final muted = highlight
        ? context.colors.onPrimary.withValues(alpha: 0.85)
        : palette.textMuted;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: highlight ? context.colors.primary : palette.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: highlight ? null : Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(height: Insets.sm),
          Text(value, style: context.texts.titleLarge?.copyWith(color: fg)),
          Text(label, style: context.texts.bodySmall?.copyWith(color: muted)),
          if (detail != null)
            Text(
              detail!,
              style: context.texts.bodySmall?.copyWith(
                color: muted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

/// Supervisión de todos los pedidos de compra.
class AdminOrdersPanel extends StatefulWidget {
  const AdminOrdersPanel({super.key});

  @override
  State<AdminOrdersPanel> createState() => _AdminOrdersPanelState();
}

class _AdminOrdersPanelState extends State<AdminOrdersPanel> {
  int _filter = 0;
  static const _filters = ['En curso', 'Entregados', 'Cancelados'];

  bool _matches(Order order) => switch (_filter) {
    0 => order.status.isOpen,
    1 => order.status == OrderStatus.delivered,
    _ =>
      order.status == OrderStatus.rejected ||
          order.status == OrderStatus.cancelledByArtisan ||
          order.status == OrderStatus.cancelledByBuyer,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final orders = app.visibleOrders.where(_matches).toList();
    return _PanelScaffold(
      filters: _filters,
      selected: _filter,
      onFilter: (index) => setState(() => _filter = index),
      emptyText: 'No hay pedidos en esta categoría.',
      header: orders.isEmpty
          ? null
          : '${orders.length} pedidos · '
                '${formatPrice(orders.fold<int>(0, (sum, order) => sum + order.total))}',
      children: [
        for (final order in orders)
          OrderCard(
            order: order,
            showBuyer: true,
            artisanName: app.artisanById(order.artisanId)?.name,
            onTap: () => showOrderDetail(context, order),
          ),
      ],
    );
  }
}

/// Supervisión de todas las reservaciones.
class AdminBookingsPanel extends StatefulWidget {
  const AdminBookingsPanel({super.key});

  @override
  State<AdminBookingsPanel> createState() => _AdminBookingsPanelState();
}

class _AdminBookingsPanelState extends State<AdminBookingsPanel> {
  int _filter = 0;
  static const _filters = ['Por responder', 'Confirmadas', 'Historial'];

  bool _matches(Booking booking) => switch (_filter) {
    0 => booking.status == BookingStatus.requested,
    1 => booking.status == BookingStatus.accepted,
    _ => booking.status.isClosed,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final bookings = app.allBookingsForAdmin.where(_matches).toList();
    return _PanelScaffold(
      filters: _filters,
      selected: _filter,
      onFilter: (index) => setState(() => _filter = index),
      emptyText: 'No hay reservaciones en esta categoría.',
      children: [
        for (final booking in bookings)
          BelSurface(
            padding: const EdgeInsets.all(Insets.md),
            onTap: () => showBookingDetail(context, booking),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.serviceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(fontSize: 14),
                      ),
                    ),
                    if (app.isSampleBooking(booking)) ...[
                      const BelPill(label: 'Ejemplo'),
                      const SizedBox(width: Insets.xs),
                    ],
                    BookingStatusChip(status: booking.status, compact: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${app.artisanById(booking.artisanId)?.name ?? 'Taller'} · '
                  '${booking.touristName}',
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                Text(
                  '${formatLongDate(booking.date)} · ${booking.timeSlot} · '
                  '${booking.people} personas · '
                  '${formatPrice(booking.totalAmount)}',
                  style: context.texts.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Moderación del catálogo: piezas y experiencias de todos los talleres.
class AdminCatalogPanel extends StatefulWidget {
  const AdminCatalogPanel({super.key});

  @override
  State<AdminCatalogPanel> createState() => _AdminCatalogPanelState();
}

class _AdminCatalogPanelState extends State<AdminCatalogPanel> {
  int _segment = 0;

  Future<String?> _askReason(BuildContext context, String what) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Ocultar $what?'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Motivo para el taller (opcional)',
            hintText: 'Ej. Fotos que no corresponden a la pieza',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context, {
    required String id,
    required String name,
    required bool product,
    required bool active,
  }) async {
    final app = context.app;
    final messenger = ScaffoldMessenger.of(context);
    String? reason;
    if (!active) {
      reason = await _askReason(context, '“$name”');
      if (reason == null) return;
    }
    final error = product
        ? await app.adminSetProductActive(id, active, reason: reason)
        : await app.adminSetServiceActive(id, active, reason: reason);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (active
                    ? '“$name” vuelve a estar publicada.'
                    : '“$name” quedó oculta. Avisamos al taller.'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final products = app.allProducts;
    final services = app.allServices;

    Widget row({
      required String id,
      required String title,
      required String subtitle,
      required String? image,
      required bool active,
      required bool product,
    }) {
      return Opacity(
        opacity: active ? 1 : 0.6,
        child: BelSurface(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: BelArtwork(
                    imagePath: image,
                    variant: product
                        ? ArtworkVariant.craft
                        : ArtworkVariant.cave,
                    seed: id.hashCode,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall?.copyWith(fontSize: 13.5),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: active,
                onChanged: (value) => _toggle(
                  context,
                  id: id,
                  name: title,
                  product: product,
                  active: value,
                ),
                activeThumbColor: context.colors.onPrimary,
                activeTrackColor: context.colors.primary,
                inactiveTrackColor: palette.surfaceMuted,
              ),
            ],
          ),
        ),
      );
    }

    return _PanelScaffold(
      filters: const ['Piezas', 'Experiencias'],
      selected: _segment,
      onFilter: (index) => setState(() => _segment = index),
      emptyText: 'Todavía no hay publicaciones.',
      header:
          'Apaga el interruptor para ocultar una publicación. El taller '
          'recibe un aviso con el motivo.',
      children: _segment == 0
          ? [
              for (final product in products)
                row(
                  id: product.id,
                  title: product.name,
                  subtitle:
                      '${app.artisanById(product.artisanId)?.name ?? 'Taller'} · '
                      '${formatPrice(product.price)}'
                      '${product.stock == null || product.madeToOrder ? '' : ' · ${product.stock} en existencia'}',
                  image: product.coverImage,
                  active: product.isActive,
                  product: true,
                ),
            ]
          : [
              for (final service in services)
                row(
                  id: service.id,
                  title: service.title,
                  subtitle:
                      '${app.artisanById(service.artisanId)?.name ?? 'Taller'} · '
                      '${formatPrice(service.pricePerPerson)} por persona · '
                      'hasta ${service.maxParticipants}',
                  image: service.coverImage,
                  active: service.isActive,
                  product: false,
                ),
            ],
    );
  }
}

/// Estructura común: filtros, una línea de encabezado y la lista.
class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({
    required this.filters,
    required this.selected,
    required this.onFilter,
    required this.children,
    required this.emptyText,
    this.header,
  });

  final List<String> filters;
  final int selected;
  final ValueChanged<int> onFilter;
  final List<Widget> children;
  final String emptyText;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.md,
        Insets.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (var i = 0; i < filters.length; i++)
                BelFilterChip(
                  label: filters[i],
                  selected: selected == i,
                  onTap: () => onFilter(i),
                ),
            ],
          ),
          if (header != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              header!,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          const SizedBox(height: Insets.md),
          if (children.isEmpty)
            BelSurface(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            )
          else
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: child,
              ),
        ],
      ),
    );
  }
}

/// Exportado para formatear periodos en otras pantallas del administrador.
String formatMonth(DateTime month) {
  const names = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

/// Tabla de rendimiento por mes (operaciones completadas).
class MonthlyPerformanceTable extends StatelessWidget {
  const MonthlyPerformanceTable({super.key, required this.months});

  final List<MonthPerformance> months;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxGross = months.fold<int>(
      1,
      (max, month) => month.gross > max ? month.gross : max,
    );
    return BelSurface(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rendimiento por mes', style: context.texts.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Operaciones completadas en cada mes.',
            style: context.texts.bodySmall?.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: Insets.md),
          for (final month in months)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatMonth(month.month),
                          style: context.texts.bodyMedium,
                        ),
                      ),
                      Text(
                        formatPrice(month.commission),
                        style: context.texts.titleSmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: month.gross / maxGross,
                      minHeight: 6,
                      backgroundColor: palette.surfaceMuted,
                      color: context.colors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${month.sales} ventas · ${month.visits} visitas · '
                    'vendido ${formatPrice(month.gross)}',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textFaint,
                      fontSize: 11,
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

import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/booking.dart';
import '../../domain/order.dart';
import '../orders/widgets/order_detail_sheet.dart';
import '../orders/widgets/order_widgets.dart';
import '../booking/widgets/booking_detail_sheet.dart';
import 'widgets/booking_card.dart';
import '../../core/widgets/bel_empty_state.dart';

/// Agenda de reservaciones del taller, filtrada por estado.
class ArtisanReservationsScreen extends StatefulWidget {
  const ArtisanReservationsScreen({super.key});

  @override
  State<ArtisanReservationsScreen> createState() =>
      _ArtisanReservationsScreenState();
}

class _ArtisanReservationsScreenState extends State<ArtisanReservationsScreen> {
  int _filter = 0;

  /// 0 = visitas, 1 = compras de piezas.
  int _kind = 0;

  static const _orderFilters = ['Por aceptar', 'Por entregar', 'Historial'];

  List<Order> _ordersFor(List<Order> all) => switch (_filter) {
    0 => [
      for (final order in all)
        if (order.status == OrderStatus.requested) order,
    ],
    // Aceptados, en preparación o listos: por fecha de recogida.
    1 =>
      [
        for (final order in all)
          if (order.status.isAcceptedByArtisan) order,
      ]..sort((a, b) {
        final aAt = a.pickupAt ?? DateTime(9999);
        final bAt = b.pickupAt ?? DateTime(9999);
        return aAt.compareTo(bAt);
      }),
    _ => [
      for (final order in all)
        if (order.status.isClosed) order,
    ],
  };

  static const _filters = ['Pendientes', 'Confirmadas', 'Historial'];

  List<Booking> _listFor(List<Booking> all) {
    switch (_filter) {
      case 0:
        return [
          for (final booking in all)
            if (booking.status == BookingStatus.requested) booking,
        ]..sort((a, b) => a.date.compareTo(b.date));
      case 1:
        return [
          for (final booking in all)
            if (booking.status == BookingStatus.accepted) booking,
        ]..sort((a, b) => a.date.compareTo(b.date));
      default:
        return [
          for (final booking in all)
            if (booking.status.isClosed) booking,
        ]..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final list = _listFor(app.visibleBookings);
    final orders = _ordersFor(app.visibleOrders);
    final filters = _kind == 0 ? _filters : _orderFilters;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Pedidos del taller',
            title: _kind == 0 ? 'Visitas' : 'Compras',
            subtitle: _kind == 0
                ? '${app.counters.pending} por responder · '
                      '${app.counters.confirmed} '
                      '${app.counters.confirmed == 1 ? 'confirmada' : 'confirmadas'}'
                : '${app.pendingOrdersCount} por aceptar',
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              0,
              Insets.page,
              Insets.md,
            ),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(
                    app.counters.pending > 0
                        ? 'Visitas (${app.counters.pending})'
                        : 'Visitas',
                  ),
                  icon: const Icon(Icons.event_available_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(
                    app.pendingOrdersCount > 0
                        ? 'Compras (${app.pendingOrdersCount})'
                        : 'Compras',
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined),
                ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() {
                _kind = value.first;
                _filter = 0;
              }),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (var i = 0; i < filters.length; i++)
                  BelFilterChip(
                    label: filters[i],
                    selected: _filter == i,
                    onTap: () => setState(() => _filter = i),
                  ),
              ],
            ),
          ),
        ),

        if (_kind == 1)
          if (orders.isEmpty)
            SliverToBoxAdapter(
              child: EmptyOrders(
                title: switch (_filter) {
                  0 => 'Sin pedidos por aceptar',
                  1 => 'Sin pedidos por entregar',
                  _ => 'Todavía no hay historial',
                },
                message:
                    'Cuando un turista compre tus piezas, el pedido aparecerá '
                    'aquí y recibirás un aviso. Tú defines cuándo lo recoge.',
              ),
            )
          else
            SliverList.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  0,
                ),
                child: OrderCard(
                  order: orders[index],
                  showBuyer: true,
                  onTap: () => showOrderDetail(context, orders[index]),
                ),
              ),
            )
        else if (list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.lg,
                Insets.page,
                0,
              ),
              child: BelEmptyState(
                icon: Icons.event_note_outlined,
                title: switch (_filter) {
                  0 => 'Sin solicitudes pendientes',
                  1 => 'Sin visitas confirmadas',
                  _ => 'Todavía no hay historial',
                },
                message:
                    'Cuando un turista solicite una visita aparecerá aquí y '
                    'recibirás un aviso en tu celular.',
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final booking = list[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  0,
                ),
                child: BookingCard(
                  booking: booking,
                  onTap: () => showBookingDetail(context, booking),
                ),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

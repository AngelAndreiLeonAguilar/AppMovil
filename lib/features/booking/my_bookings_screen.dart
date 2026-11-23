import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/booking_status_chip.dart';
import '../../core/widgets/page_header.dart';
import '../../domain/booking.dart';
import '../notifications/widgets/notifications_bell.dart';
import 'booking_flow_screen.dart';
import 'widgets/booking_detail_sheet.dart';
import '../account/account_screen.dart';
import '../../domain/order.dart';
import '../orders/widgets/order_detail_sheet.dart';
import '../orders/widgets/order_widgets.dart';
import '../orders/cart_screen.dart';
import '../../core/widgets/bel_empty_state.dart';

/// "Actividad": visitas reservadas y compras del turista, por separado.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  /// 0 = visitas, 1 = compras.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (_tab == 1) return _buildOrders(context);
    final bookings = app.visibleBookings;
    final upcoming = [
      for (final booking in bookings)
        if (booking.status.isActive) booking,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final history = [
      for (final booking in bookings)
        if (booking.status.isClosed) booking,
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _header(
            subtitle: upcoming.isEmpty
                ? 'Solicita una visita y sigue su estado aquí.'
                : '${upcoming.length} ${upcoming.length == 1 ? 'visita activa' : 'visitas activas'}',
          ),
        ),
        SliverToBoxAdapter(child: _switcher()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              0,
              Insets.page,
              Insets.lg,
            ),
            child: BelButton(
              label: 'Nueva reserva',
              icon: Icons.add_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookingFlowScreen(),
                ),
              ),
            ),
          ),
        ),

        if (bookings.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: BelEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Aún no tienes visitas',
                message:
                    'Explora los talleres y solicita tu primera visita a las '
                    'cuevas de Bécal.',
                actionLabel: 'Reservar una visita',
                actionIcon: Icons.add_rounded,
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BookingFlowScreen(),
                  ),
                ),
              ),
            ),
          ),

        if (upcoming.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(text: 'PRÓXIMAS')),
          SliverList.builder(
            itemCount: upcoming.length,
            itemBuilder: (context, index) {
              final booking = upcoming[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  0,
                  Insets.page,
                  Insets.sm,
                ),
                child: _TouristBookingCard(booking: booking),
              );
            },
          ),
        ],

        if (history.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(text: 'HISTORIAL')),
          SliverList.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final booking = history[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  0,
                  Insets.page,
                  Insets.sm,
                ),
                child: _TouristBookingCard(booking: booking),
              );
            },
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }

  Widget _header({required String subtitle}) => PageHeader(
    eyebrow: 'Tu actividad',
    title: _tab == 0 ? 'Mis visitas' : 'Mis compras',
    subtitle: subtitle,
    actions: [
      if (_tab == 1) const CartButton(),
      const NotificationsBell(),
      const SizedBox(width: Insets.xs),
      const AccountAvatarButton(size: 38),
    ],
  );

  Widget _switcher() => Padding(
    padding: const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, Insets.lg),
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          label: Text('Visitas'),
          icon: Icon(Icons.event_available_outlined),
        ),
        ButtonSegment(
          value: 1,
          label: Text('Compras'),
          icon: Icon(Icons.shopping_bag_outlined),
        ),
      ],
      selected: {_tab},
      showSelectedIcon: false,
      onSelectionChanged: (value) => setState(() => _tab = value.first),
    ),
  );

  Widget _buildOrders(BuildContext context) {
    final orders = context.app.visibleOrders;
    final open = [
      for (final order in orders)
        if (order.status.isOpen) order,
    ];
    final closed = [
      for (final order in orders)
        if (order.status.isClosed) order,
    ];

    Widget list(List<Order> items) => SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          0,
          Insets.page,
          Insets.sm,
        ),
        child: OrderCard(
          order: items[index],
          artisanName: context.app.artisanById(items[index].artisanId)?.name,
          onTap: () => showOrderDetail(context, items[index]),
        ),
      ),
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _header(
            subtitle: open.isEmpty
                ? 'Compra piezas desde el catálogo y sigue tus pedidos aquí.'
                : '${open.length} ${open.length == 1 ? 'pedido en curso' : 'pedidos en curso'}',
          ),
        ),
        SliverToBoxAdapter(child: _switcher()),
        if (orders.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyOrders(
              title: 'Aún no tienes compras',
              message:
                  'Agrega piezas del catálogo a tu carrito y confirma tu '
                  'pedido. Lo recoges en el taller.',
            ),
          ),
        if (open.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(text: 'EN CURSO')),
          list(open),
        ],
        if (closed.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionLabel(text: 'HISTORIAL')),
          list(closed),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.sm,
        Insets.page,
        Insets.sm,
      ),
      child: Text(
        text,
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textMuted,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _TouristBookingCard extends StatelessWidget {
  const _TouristBookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BelSurface(
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
              const SizedBox(width: Insets.sm),
              BookingStatusChip(status: booking.status, compact: true),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            '${formatLongDate(booking.date)} · ${booking.timeSlot} · '
            '${booking.people} ${booking.people == 1 ? 'persona' : 'personas'}',
            style: context.texts.bodySmall?.copyWith(
              color: palette.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                booking.folio,
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textFaint,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                formatPrice(booking.totalAmount),
                style: context.texts.titleSmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

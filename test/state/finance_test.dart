import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/booking.dart';
import 'package:bel_aaktun/domain/finance.dart';
import 'package:bel_aaktun/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cálculo de comisiones', () {
    test('desglosa comisión e ingreso neto', () {
      final split = CommissionSplit.of(4200, 1000);
      expect(split.commission, 420);
      expect(split.net, 3780);
    });

    test('redondea al peso más cercano', () {
      expect(CommissionSplit.of(355, 1500).commission, 53);
    });

    test('formatea tasas', () {
      expect(formatRate(1000), '10 %');
      expect(formatRate(1250), '12.5 %');
      expect(formatRate(1525), '15.25 %');
    });

    test('solo las operaciones completadas son ingreso', () {
      final now = DateTime(2026, 11, 1);
      LedgerEntry entry(
        String id,
        LedgerStatus status, {
        bool settled = false,
      }) => LedgerEntry(
        id: id,
        source: LedgerSource.sale,
        sourceId: id,
        folio: id,
        artisanId: 'art-01',
        customerName: 'Luis',
        description: 'Sombrero',
        gross: 1000,
        rateBps: 1000,
        commission: 100,
        status: status,
        createdAt: now,
        updatedAt: now,
        settledAt: settled ? now : null,
        settlementRef: settled ? 'REC-1' : null,
      );
      final summary = FinanceSummary.of([
        entry('a', LedgerStatus.earned),
        entry('b', LedgerStatus.earned, settled: true),
        entry('c', LedgerStatus.pending),
        entry('d', LedgerStatus.voided),
      ]);
      expect(summary.commissionEarned, 200);
      expect(summary.commissionToSettle, 100);
      expect(summary.commissionSettled, 100);
      expect(summary.commissionPending, 100);
      expect(summary.artisanNetEarned, 1800);
      expect(summary.voidedCount, 1);
    });
  });

  group('Registro de comisiones por venta', () {
    late MemoryStore store;

    Future<AppController> open() => AppController.load(
      authApi: LocalAuthApi(store),
      deviceNotifications: SilentDeviceNotifications(),
      store: store,
    );

    setUp(() => store = MemoryStore());

    /// Un turista compra una pieza de $1,000 del taller de Elena.
    Future<String> buyFromElena() async {
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.upsertProduct(
        name: 'Sombrero de prueba',
        category: 'Sombreros',
        description: 'x',
        technique: 'y',
        price: 1000,
        madeToOrder: false,
        isActive: true,
        stock: 5,
      );
      final product = shop.myProducts.firstWhere(
        (item) => item.name == 'Sombrero de prueba',
      );
      await shop.signOut();
      final buyer = await open();
      await buyer.register(
        nombre: 'Luis Uc',
        email: 'luis${DateTime.now().microsecondsSinceEpoch}@correo.mx',
        password: 'Clave1234',
      );
      await buyer.addToCart(product);
      final result = await buyer.checkout(name: 'Luis Uc', phone: '9810000000');
      await buyer.signOut();
      return result.orders.single.id;
    }

    test('un pedido aceptado y entregado genera un solo asiento', () async {
      final orderId = await buyFromElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');

      // Pendiente de aceptación: todavía no hay comisión.
      expect(shop.ledgerEntryFor(LedgerSource.sale, orderId), isNull);

      final pickup = DateTime.now().add(const Duration(days: 1));
      await shop.changeOrderStatus(
        orderId,
        OrderStatus.accepted,
        pickupAt: pickup,
      );
      var entry = shop.ledgerEntryFor(LedgerSource.sale, orderId)!;
      expect(entry.status, LedgerStatus.pending);
      expect(entry.commission, 100);
      expect(entry.artisanNet, 900);
      expect(shop.financeSummary().commissionEarned, 0);

      await shop.changeOrderStatus(orderId, OrderStatus.preparing);
      await shop.changeOrderStatus(orderId, OrderStatus.ready);
      await shop.changeOrderStatus(orderId, OrderStatus.delivered);

      final entries = shop.ledgerEntries
          .where((item) => item.sourceId == orderId)
          .toList();
      expect(entries, hasLength(1));
      entry = entries.single;
      expect(entry.status, LedgerStatus.earned);
      expect(entry.isPendingSettlement, isTrue);
      expect(shop.financeSummary().commissionEarned, 100);
    });

    test('un pedido cancelado anula la comisión y no cuenta', () async {
      final orderId = await buyFromElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.changeOrderStatus(orderId, OrderStatus.accepted);
      await shop.changeOrderStatus(orderId, OrderStatus.cancelledByArtisan);
      final entry = shop.ledgerEntryFor(LedgerSource.sale, orderId)!;
      expect(entry.status, LedgerStatus.voided);
      expect(shop.financeSummary().commissionEarned, 0);
      expect(shop.financeSummary().commissionPending, 0);
    });

    test('un pedido rechazado no genera asiento', () async {
      final orderId = await buyFromElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.changeOrderStatus(orderId, OrderStatus.rejected);
      expect(shop.ledgerEntryFor(LedgerSource.sale, orderId), isNull);
    });

    test('cambiar la tasa no altera pedidos ya aceptados', () async {
      final orderId = await buyFromElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.changeOrderStatus(orderId, OrderStatus.accepted);
      await shop.signOut();

      final admin = await open();
      await admin.signIn('admin@belaaktun.mx', 'Becal2026');
      expect(await admin.setCommissionRates(saleRateBps: 2000), isNull);
      expect(admin.commissionSettings.saleRateBps, 2000);
      expect(admin.ledgerEntryFor(LedgerSource.sale, orderId)!.commission, 100);
    });

    test(
      'solo la administración cambia tasas y registra liquidaciones',
      () async {
        final orderId = await buyFromElena();
        final shop = await open();
        await shop.signIn('elena@belaaktun.mx', 'Becal2026');
        expect(await shop.setCommissionRates(saleRateBps: 0), isNotNull);
        await shop.changeOrderStatus(
          orderId,
          OrderStatus.accepted,
          pickupAt: DateTime.now().add(const Duration(days: 1)),
        );
        await shop.changeOrderStatus(orderId, OrderStatus.ready);
        await shop.changeOrderStatus(orderId, OrderStatus.delivered);
        final entryId = shop.ledgerEntryFor(LedgerSource.sale, orderId)!.id;
        expect(await shop.registerSettlement(entryId, 'REC-1'), isNotNull);
        await shop.signOut();

        final admin = await open();
        await admin.signIn('admin@belaaktun.mx', 'Becal2026');
        expect(await admin.registerSettlement(entryId, ''), isNotNull);
        expect(await admin.registerSettlement(entryId, 'REC-001'), isNull);
        expect(admin.financeSummary().commissionSettled, 100);
        expect(await admin.registerSettlement(entryId, 'REC-002'), isNotNull);
      },
    );
  });

  group('Registro de comisiones por visita', () {
    late MemoryStore store;

    Future<AppController> open() => AppController.load(
      authApi: LocalAuthApi(store),
      deviceNotifications: SilentDeviceNotifications(),
      store: store,
    );

    setUp(() => store = MemoryStore());

    /// Un turista reserva para 2 personas una experiencia de Elena.
    Future<String> bookWithElena() async {
      final tourist = await open();
      await tourist.register(
        nombre: 'Ana Pech',
        email: 'ana${DateTime.now().microsecondsSinceEpoch}@correo.mx',
        password: 'Clave1234',
      );
      final service = tourist.activeServices.firstWhere(
        (item) => item.artisanId == 'art-01',
      );
      final booking = await tourist.requestBooking(
        service: service,
        date: DateTime.now().add(const Duration(days: 5)),
        timeSlot: '10:30',
        people: 2,
        name: 'Ana Pech',
        phone: '9810000000',
      );
      await tourist.signOut();
      return booking.id;
    }

    test('una visita confirmada y realizada devenga la comisión', () async {
      final bookingId = await bookWithElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      final booking = shop.bookingById(bookingId)!;

      // Solicitud: todavía sin comisión.
      expect(shop.ledgerEntryFor(LedgerSource.visit, bookingId), isNull);

      await shop.changeBookingStatus(bookingId, BookingStatus.accepted);
      var entry = shop.ledgerEntryFor(LedgerSource.visit, bookingId)!;
      expect(entry.status, LedgerStatus.pending);
      expect(entry.gross, booking.totalAmount);
      expect(
        entry.commission,
        CommissionSplit.of(booking.totalAmount, 1500).commission,
      );

      await shop.changeBookingStatus(bookingId, BookingStatus.completed);
      entry = shop.ledgerEntryFor(LedgerSource.visit, bookingId)!;
      expect(entry.status, LedgerStatus.earned);
      expect(
        shop.financeSummary(source: LedgerSource.visit).commissionEarned,
        entry.commission,
      );
      expect(
        shop.ledgerEntries.where((item) => item.sourceId == bookingId),
        hasLength(1),
      );
    });

    test('un no-show anula la comisión', () async {
      final bookingId = await bookWithElena();
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.changeBookingStatus(bookingId, BookingStatus.accepted);
      await shop.changeBookingStatus(bookingId, BookingStatus.noShow);
      expect(
        shop.ledgerEntryFor(LedgerSource.visit, bookingId)!.status,
        LedgerStatus.voided,
      );
      expect(shop.financeSummary().commissionEarned, 0);
    });

    test('las reservaciones de ejemplo no generan comisiones', () async {
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      expect(
        shop.ledgerEntries.where(
          (entry) => entry.sourceId.startsWith('bk-seed-'),
        ),
        isEmpty,
      );
    });
  });

  group('Estadísticas del taller', () {
    test('el ingreso neto por semana solo suma lo completado', () {
      final now = DateTime(2026, 11, 20, 12); // viernes
      LedgerEntry entry(String id, LedgerStatus status, DateTime? earnedAt) =>
          LedgerEntry(
            id: id,
            source: LedgerSource.sale,
            sourceId: id,
            folio: id,
            artisanId: 'art-01',
            customerName: 'Luis',
            description: 'Sombrero',
            gross: 1000,
            rateBps: 1000,
            commission: 100,
            status: status,
            createdAt: now,
            updatedAt: now,
            earnedAt: earnedAt,
          );
      final weeks = netByWeek([
        entry('a', LedgerStatus.earned, DateTime(2026, 11, 18)),
        entry('b', LedgerStatus.earned, DateTime(2026, 11, 10)),
        entry('c', LedgerStatus.pending, null),
      ], now: now);
      expect(weeks, hasLength(4));
      expect(weeks.last.amount, 900);
      expect(weeks[2].amount, 900);
      expect(weeks.first.amount, 0);
    });

    test('el taller ajusta existencias y ve alertas de inventario', () async {
      final store = MemoryStore();
      final shop = await AppController.load(
        authApi: LocalAuthApi(store),
        deviceNotifications: SilentDeviceNotifications(),
        store: store,
      );
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.upsertProduct(
        name: 'Bolso de prueba',
        category: 'Bolsos',
        description: 'x',
        technique: 'y',
        price: 800,
        madeToOrder: false,
        isActive: true,
        stock: 6,
      );
      final product = shop.myProducts.firstWhere(
        (item) => item.name == 'Bolso de prueba',
      );
      expect(shop.lowStockProducts.contains(product), isFalse);
      expect(await shop.setProductStock(product.id, 1), isNull);
      expect(shop.productById(product.id)!.stock, 1);
      expect(
        shop.lowStockProducts.map((item) => item.id),
        contains(product.id),
      );
      expect(await shop.setProductStock(product.id, -1), isNotNull);
    });
  });
}

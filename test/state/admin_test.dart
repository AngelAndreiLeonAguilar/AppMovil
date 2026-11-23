import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/finance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryStore store;
  late SilentDeviceNotifications device;

  Future<AppController> open() => AppController.load(
    authApi: LocalAuthApi(store),
    deviceNotifications: device,
    store: store,
  );

  setUp(() {
    store = MemoryStore();
    device = SilentDeviceNotifications();
  });

  test(
    'la administración oculta una pieza y el taller recibe el aviso',
    () async {
      final admin = await open();
      await admin.signIn('admin@belaaktun.mx', 'Becal2026');
      final product = admin.allProducts.firstWhere(
        (item) => item.artisanId == 'art-01',
      );
      expect(
        await admin.adminSetProductActive(
          product.id,
          false,
          reason: 'Fotos que no corresponden',
        ),
        isNull,
      );
      expect(admin.productById(product.id)!.isActive, isFalse);
      expect(
        admin.activeProducts.any((item) => item.id == product.id),
        isFalse,
      );
      await admin.signOut();

      final shop = await open();
      device.shown.clear();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      expect(
        shop.myNotifications.any(
          (item) => item.body.contains('Fotos que no corresponden'),
        ),
        isTrue,
      );
    },
  );

  test('solo la administración modera y ve todas las operaciones', () async {
    final shop = await open();
    await shop.signIn('elena@belaaktun.mx', 'Becal2026');
    final product = shop.myProducts.first;
    expect(await shop.adminSetProductActive(product.id, false), isNotNull);
    expect(shop.allBookingsForAdmin, isEmpty);
    expect(shop.platformStats.ordersOpen, 0);
  });

  test('las cifras generales no cuentan reservaciones de ejemplo', () async {
    final admin = await open();
    await admin.signIn('admin@belaaktun.mx', 'Becal2026');
    final stats = admin.platformStats;
    expect(stats.bookingsCompleted, 0);
    expect(stats.bookingsConfirmed, 0);
    expect(admin.allBookingsForAdmin, isNotEmpty);
    expect(admin.allBookingsForAdmin.every(admin.isSampleBooking), isTrue);
  });

  test('el rendimiento mensual agrupa lo completado por mes', () {
    final now = DateTime(2026, 11, 22);
    LedgerEntry entry(String id, DateTime earned, LedgerSource source) =>
        LedgerEntry(
          id: id,
          source: source,
          sourceId: id,
          folio: id,
          artisanId: 'art-01',
          customerName: 'Luis',
          description: 'x',
          gross: 1000,
          rateBps: 1000,
          commission: 100,
          status: LedgerStatus.earned,
          createdAt: earned,
          updatedAt: earned,
          earnedAt: earned,
        );
    final months = monthlyPerformance([
      entry('a', DateTime(2026, 11, 3), LedgerSource.sale),
      entry('b', DateTime(2026, 11, 20), LedgerSource.visit),
      entry('c', DateTime(2026, 10, 15), LedgerSource.sale),
    ], now: now);
    expect(months, hasLength(6));
    expect(months.first.month, DateTime(2026, 11));
    expect(months.first.commission, 200);
    expect(months.first.sales, 1);
    expect(months.first.visits, 1);
    expect(months[1].gross, 1000);
    expect(months[2].operations, 0);
  });
}

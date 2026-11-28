import 'package:bel_aaktun/core/config/app_config.dart';
import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/demo_content.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/app_notification.dart';
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
    AppConfig.enforceSubscription = true;
  });

  tearDown(() {
    AppConfig.enforceSubscription = false;
    AppConfig.seedSampleData = true;
  });

  test('un taller sin mensualidad está fuera de servicio y no vende', () async {
    final app = await open();
    await app.signIn('turista@belaaktun.mx', 'Becal2026');
    expect(app.isArtisanInService('art-01'), isFalse);

    final product = app.allProducts.firstWhere((p) => p.artisanId == 'art-01');
    final error = await app.addToCart(product);
    expect(error, contains('fuera de servicio'));

    final service = app.activeServices.firstWhere(
      (s) => s.artisanId == 'art-01',
    );
    expect(
      app.bookingAvailabilityError(
        service: service,
        date: DateTime.now().add(const Duration(days: 2)),
        timeSlot: '10:00',
        people: 1,
      ),
      contains('fuera de servicio'),
    );
    expect(app.bookableServices.any((s) => s.artisanId == 'art-01'), isFalse);
  });

  test('el taller registra su pago y la administración lo activa', () async {
    final shop = await open();
    await shop.signIn('elena@belaaktun.mx', 'Becal2026');
    expect(await shop.reportSubscriptionPayment('x'), isNotNull);
    expect(await shop.reportSubscriptionPayment('SPEI 0098123'), isNull);
    expect(shop.artisan!.subscriptionPendingRef, 'SPEI 0098123');
    await shop.signOut();

    final admin = await open();
    await admin.signIn('admin@belaaktun.mx', 'Becal2026');
    expect(admin.pendingSubscriptionCount, 1);
    final today = DateTime(2026, 12, 1);
    expect(await admin.adminConfirmSubscription('art-01', now: today), isNull);
    final until = admin.artisanById('art-01')!.subscriptionUntil!;
    expect(until, DateTime(2026, 12, 31));
    expect(admin.artisanById('art-01')!.hasPendingPayment, isFalse);
    expect(admin.isArtisanInService('art-01', now: today), isTrue);
    expect(
      admin.isArtisanInService('art-01', now: DateTime(2027, 1, 1)),
      isFalse,
    );
    await admin.signOut();

    final again = await open();
    await again.signIn('elena@belaaktun.mx', 'Becal2026');
    expect(
      again.myNotifications.any(
        (n) =>
            n.type == AppNotificationType.subscription &&
            n.title.contains('activo'),
      ),
      isTrue,
    );
  });

  test('un taller activo vende y al quedar fuera de servicio deja de vender',
      () async {
    final admin = await open();
    await admin.signIn('admin@belaaktun.mx', 'Becal2026');
    await admin.adminConfirmSubscription('art-01');
    await admin.signOut();

    final tourist = await open();
    await tourist.signIn('turista@belaaktun.mx', 'Becal2026');
    final product = tourist.allProducts.firstWhere(
      (p) => p.artisanId == 'art-01' && p.price != null && !p.isSoldOut,
    );
    expect(await tourist.addToCart(product), isNull);
    await tourist.signOut();

    final admin2 = await open();
    await admin2.signIn('admin@belaaktun.mx', 'Becal2026');
    expect(await admin2.adminSetOutOfService('art-01'), isNull);
    expect(admin2.isArtisanInService('art-01'), isFalse);
    await admin2.signOut();

    final tourist2 = await open();
    await tourist2.signIn('turista@belaaktun.mx', 'Becal2026');
    final result = await tourist2.checkout(
      name: 'Ana Canul',
      phone: '9811234567',
    );
    expect(result.error, contains('fuera de servicio'));
  });

  test('solo la administración confirma y solo el taller avisa su pago',
      () async {
    final tourist = await open();
    await tourist.signIn('turista@belaaktun.mx', 'Becal2026');
    expect(await tourist.reportSubscriptionPayment('SPEI 1'), isNotNull);
    expect(await tourist.adminConfirmSubscription('art-01'), isNotNull);
    expect(await tourist.adminSetOutOfService('art-01'), isNotNull);
  });

  test('la versión del piloto trae un taller de ejemplo de cada tipo',
      () async {
    AppConfig.seedSampleData = false;
    final app = await open();
    final active = app.artisanById(DemoContent.showcaseActiveId);
    final inactive = app.artisanById(DemoContent.showcaseInactiveId);
    expect(active, isNotNull);
    expect(inactive, isNotNull);
    expect(app.isArtisanInService(DemoContent.showcaseActiveId), isTrue);
    expect(app.isArtisanInService(DemoContent.showcaseInactiveId), isFalse);
    expect(app.artisans.first.id, DemoContent.showcaseActiveId);
    // Los de ejemplo nunca reciben pedidos reales.
    expect(
      app.artisanServiceBlock(DemoContent.showcaseActiveId),
      contains('ejemplo'),
    );
    expect(app.isSampleArtisan(DemoContent.showcaseInactiveId), isTrue);
    expect(
      app.allProducts.where((p) => p.artisanId.startsWith('art-muestra')),
      hasLength(2),
    );
  });
}

import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/booking_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryStore store;

  Future<AppController> open() => AppController.load(
    authApi: LocalAuthApi(store),
    deviceNotifications: SilentDeviceNotifications(),
    store: store,
  );

  setUp(() => store = MemoryStore());

  /// Día dentro del horizonte y lejos de las reservaciones de ejemplo.
  DateTime futureDay(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + days);
  }

  test('el cupo de un horario baja con cada reservación activa', () async {
    final shop = await open();
    await shop.signIn('elena@belaaktun.mx', 'Becal2026');
    await shop.upsertService(
      title: 'Visita corta',
      description: 'x',
      durationMinutes: 60,
      pricePerPerson: 100,
      depositPercent: 0,
      maxParticipants: 4,
      isActive: true,
    );
    final service = shop.myServices.firstWhere(
      (s) => s.title == 'Visita corta',
    );
    await shop.signOut();

    final tourist = await open();
    await tourist.register(
      nombre: 'Ana Pech',
      email: 'ana@correo.mx',
      password: 'Clave1234',
    );
    final day = futureDay(9);
    expect(tourist.spotsLeft(service, day, '10:30'), 4);
    await tourist.requestBooking(
      service: service,
      date: day,
      timeSlot: '10:30',
      people: 3,
      name: 'Ana Pech',
      phone: '9810000000',
    );
    expect(tourist.spotsLeft(service, day, '10:30'), 1);
    expect(
      tourist.bookingAvailabilityError(
        service: service,
        date: day,
        timeSlot: '10:30',
        people: 2,
      ),
      'Solo queda 1 lugar en ese horario.',
    );
    await expectLater(
      tourist.requestBooking(
        service: service,
        date: day,
        timeSlot: '10:30',
        people: 2,
        name: 'Ana Pech',
        phone: '9810000000',
      ),
      throwsA(isA<BookingRuleError>()),
    );
  });

  test('respeta los días y el horario del taller', () async {
    final shop = await open();
    await shop.signIn('elena@belaaktun.mx', 'Becal2026');
    final artisan = shop.artisan!;
    // Abre solo lunes a viernes de 09:00 a 12:00.
    await shop.updateArtisanProfile(
      artisan.copyWith(
        openDays: [1, 2, 3, 4, 5],
        openTime: '09:00',
        closeTime: '12:00',
      ),
    );
    final service = shop.myServices.firstWhere((s) => s.isActive);

    var day = futureDay(3);
    while (day.weekday != DateTime.sunday) {
      day = day.add(const Duration(days: 1));
    }
    expect(shop.isWorkshopOpenOn(service, day), isFalse);
    expect(shop.slotsFor(service, day), isEmpty);

    final monday = day.add(const Duration(days: 1));
    final slots = shop.slotsFor(service, monday);
    // La visita debe terminar antes de cerrar.
    for (final slot in slots) {
      final parts = slot.split(':');
      final start = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      expect(start >= 9 * 60, isTrue);
      expect(start + service.durationMinutes <= 12 * 60, isTrue);
    }
    expect(slots.contains('16:00'), isFalse);
  });

  test('no se puede reservar en el pasado ni con poca anticipación', () async {
    final app = await open();
    await app.register(
      nombre: 'Ana Pech',
      email: 'ana@correo.mx',
      password: 'Clave1234',
    );
    final service = app.activeServices.first;
    final yesterday = futureDay(-1);
    expect(
      app.bookingAvailabilityError(
        service: service,
        date: yesterday,
        timeSlot: '10:30',
        people: 1,
      ),
      isNotNull,
    );
    // Hoy a las 11:00: el horario de las 09:00 ya pasó.
    final now = DateTime(2026, 11, 22, 11);
    expect(app.slotsFor(service, now, now: now).contains('09:00'), isFalse);
  });
}

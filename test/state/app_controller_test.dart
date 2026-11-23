import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/demo_content.dart';
import 'package:bel_aaktun/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppController> loadWithFake() =>
      AppController.load(authApi: FakeAuthApi());

  test('una solicitud del turista llega al taller y persiste', () async {
    final tourist = await loadWithFake();
    expect(await tourist.signIn('turista@test.mx', 'Clave1234'), isNull);

    final service = DemoContent.experiences.first;
    final booking = await tourist.requestBooking(
      service: service,
      date: DateTime.now().add(const Duration(days: 3)),
      timeSlot: '10:30',
      people: 2,
      name: 'Turista demo',
      phone: '+52 981 000 0000',
    );

    expect(booking.status, BookingStatus.requested);
    expect(booking.depositAmount, greaterThan(0));

    // Otro arranque de la app: el taller ve la solicitud.
    final artisan = await loadWithFake();
    expect(await artisan.signIn('elena@test.mx', 'Clave1234'), isNull);
    expect(
      artisan.visibleBookings.any((item) => item.id == booking.id),
      isTrue,
    );

    final error = await artisan.changeBookingStatus(
      booking.id,
      BookingStatus.accepted,
    );
    expect(error, isNull);

    // El turista ve el cambio de estado tras reiniciar.
    final reloaded = await loadWithFake();
    expect(await reloaded.signIn('turista@test.mx', 'Clave1234'), isNull);
    expect(reloaded.bookingById(booking.id)?.status, BookingStatus.accepted);
  });

  test('un artesano no ve reservas de otro taller', () async {
    final artisan = await loadWithFake();
    expect(await artisan.signIn('elena@test.mx', 'Clave1234'), isNull);

    for (final booking in artisan.visibleBookings) {
      expect(booking.artisanId, 'art-01');
    }
  });

  test('el anticipo se calcula con el porcentaje del servicio', () async {
    final tourist = await loadWithFake();
    expect(await tourist.signIn('turista@test.mx', 'Clave1234'), isNull);

    final service = DemoContent.experiences.first;
    final booking = await tourist.requestBooking(
      service: service,
      date: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '09:00',
      people: 3,
      name: 'Turista demo',
      phone: '+52 981 000 0000',
    );

    final expectedTotal = service.pricePerPerson * 3;
    expect(booking.totalAmount, expectedTotal);
    expect(
      booking.depositAmount,
      (expectedTotal * service.depositPercent / 100).round(),
    );
    expect(booking.depositStatus, DepositStatus.simulatedPaid);
  });

  test('credenciales incorrectas no abren sesión', () async {
    final controller = await loadWithFake();
    final error = await controller.signIn('turista@test.mx', 'Incorrecta1');

    expect(error, isNotNull);
    expect(controller.isSignedIn, isFalse);
  });
}

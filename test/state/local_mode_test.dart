import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/api_client.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/app_notification.dart';
import 'package:bel_aaktun/domain/booking.dart';
import 'package:bel_aaktun/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAuthApi', () {
    test('registra, inicia sesión y recuerda la cuenta tras reiniciar', () async {
      final store = MemoryStore();
      final api = LocalAuthApi(store);

      final session = await api.register(
        nombre: 'Ana Canul',
        email: 'Ana@Correo.mx',
        password: 'Clave1234',
        telefono: '9811234567',
      );
      expect(session.user.role, UserRole.tourist);
      expect(session.user.email, 'ana@correo.mx');

      // Una instancia nueva lee lo guardado (como al reabrir la app).
      final reopened = LocalAuthApi(store);
      final login = await reopened.login(
        email: 'ana@correo.mx',
        password: 'Clave1234',
      );
      expect(login.user.name, 'Ana Canul');
      final me = await reopened.me(session.accessToken);
      expect(me.user.id, session.user.id);
    });

    test('no guarda la contraseña en claro', () async {
      final store = MemoryStore();
      await LocalAuthApi(store).register(
        nombre: 'Ana Canul',
        email: 'ana@correo.mx',
        password: 'Secreta123',
      );
      expect(store.read('local.auth.v1'), isNot(contains('Secreta123')));
    });

    test('rechaza correos repetidos y contraseñas incorrectas', () async {
      final api = LocalAuthApi(MemoryStore());
      await api.register(
        nombre: 'Ana Canul',
        email: 'ana@correo.mx',
        password: 'Clave1234',
      );
      expect(
        () => api.register(
          nombre: 'Otra',
          email: 'ANA@correo.mx',
          password: 'Clave1234',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => api.login(email: 'ana@correo.mx', password: 'Mala12345'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    });

    test('incluye cuentas de demostración', () async {
      final api = LocalAuthApi(MemoryStore());
      final admin = await api.login(
        email: 'admin@belaaktun.mx',
        password: 'Becal2026',
      );
      expect(admin.user.role, UserRole.admin);
      final elena = await api.login(
        email: 'elena@belaaktun.mx',
        password: 'Becal2026',
      );
      expect(elena.user.artisanId, 'art-01');
    });

    test('una cuenta suspendida no puede entrar', () async {
      final api = LocalAuthApi(MemoryStore());
      final admin = await api.login(
        email: 'admin@belaaktun.mx',
        password: 'Becal2026',
      );
      final tourist = await api.register(
        nombre: 'Ana Canul',
        email: 'ana@correo.mx',
        password: 'Clave1234',
      );
      await api.suspendUser(
        admin.accessToken,
        int.parse(tourist.user.id),
        'Prueba de suspensión',
      );
      expect(
        () => api.login(email: 'ana@correo.mx', password: 'Clave1234'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });
  });

  group('Modo local completo', () {
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

    test('un artesano se registra y su taller se activa con ficha propia',
        () async {
      final app = await open();
      expect(
        await app.register(
          nombre: 'Rosa Pech',
          email: 'rosa@correo.mx',
          password: 'Clave1234',
          telefono: '9817654321',
        ),
        isNull,
      );
      expect(
        await app.submitArtisanApplication(
          nombreTaller: 'Cueva Santa Rosa',
          descripcion: 'Taller familiar de sombreros finos de jipi.',
          telefono: '9817654321',
          oficio: 'Sombrerero tradicional',
        ),
        isNull,
      );

      expect(app.isArtisan, isTrue);
      final shop = app.artisan!;
      expect(shop.name, 'Cueva Santa Rosa');
      expect(shop.craft, 'Sombrerero tradicional');
      expect(shop.ownerUserId, app.user!.id);
      expect(app.artisans.map((item) => item.id), contains(shop.id));

      // Fotos y horario se guardan en la ficha.
      await app.updateArtisanProfile(
        shop.copyWith(
          imagePath: 'assets/images/demo.jpg',
          openDays: [1, 2, 3, 4, 5],
          openTime: '09:00',
          closeTime: '17:00',
        ),
      );
      final reopened = await open();
      expect(reopened.artisan?.imagePath, 'assets/images/demo.jpg');
      expect(reopened.artisan?.hasSchedule, isTrue);
    });

    test('la reserva de un turista avisa al taller en su teléfono', () async {
      // 1. El artesano crea su cuenta y publica una experiencia.
      final artisanApp = await open();
      await artisanApp.register(
        nombre: 'Rosa Pech',
        email: 'rosa@correo.mx',
        password: 'Clave1234',
      );
      await artisanApp.submitArtisanApplication(
        nombreTaller: 'Cueva Santa Rosa',
        descripcion: 'Taller familiar de sombreros finos de jipi.',
      );
      expect(
        await artisanApp.upsertService(
          title: 'Recorrido por mi cueva',
          description: 'Visita guiada',
          durationMinutes: 60,
          pricePerPerson: 150,
          depositPercent: 30,
          maxParticipants: 8,
          isActive: true,
          photos: const ['assets/images/cueva.jpg'],
        ),
        isNull,
      );
      final service = artisanApp.myServices.first;
      expect(service.coverImage, 'assets/images/cueva.jpg');
      await artisanApp.signOut();

      // 2. Un turista reserva en el mismo teléfono.
      final touristApp = await open();
      await touristApp.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      device.shown.clear();
      final booking = await touristApp.requestBooking(
        service: touristApp.serviceById(service.id)!,
        date: DateTime.now().add(const Duration(days: 3)),
        timeSlot: '10:30',
        people: 2,
        name: 'Luis Uc',
        phone: '9810000000',
      );
      // El turista recibe la confirmación de envío en su barra.
      expect(device.shown, ['Solicitud enviada']);
      await touristApp.signOut();

      // 3. El artesano vuelve a entrar y recibe el aviso en la barra.
      final again = await open();
      device.shown.clear();
      await again.signIn('rosa@correo.mx', 'Clave1234');
      expect(device.shown, contains('Nueva solicitud de Luis Uc'));
      expect(
        again.myNotifications.first.type,
        AppNotificationType.newBooking,
      );

      // 4. Al aceptar se programan los recordatorios de la visita.
      expect(
        await again.changeBookingStatus(booking.id, BookingStatus.accepted),
        isNull,
      );
      expect(device.scheduled, hasLength(2));
      expect(device.scheduled.first.title, 'Mañana recibes a Luis Uc');
    });

    test('el turista puede poner foto de perfil', () async {
      final app = await open();
      await app.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      await app.setMyAvatar('assets/images/luis.jpg');
      final reopened = await open();
      expect(reopened.myAvatar, 'assets/images/luis.jpg');
    });
  });
}

import 'dart:convert';

import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/data/services/sync_store.dart';
import 'package:bel_aaktun/domain/booking.dart';
import 'package:bel_aaktun/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Imita `tools/servidor_pruebas/servidor.py` en memoria.
class FakeServer {
  final Map<String, String> values = {};
  int version = 0;
  bool down = false;

  MockClient client() => MockClient((request) async {
    if (down) throw http.ClientException('sin red');
    final path = request.url.path;
    if (path == '/health') {
      return http.Response(jsonEncode({'status': 'ok', 'app': 'bel-aaktun'}), 200);
    }
    if (path == '/state' && request.method == 'GET') {
      return http.Response.bytes(
        utf8.encode(jsonEncode({'version': version, 'values': values})),
        200,
      );
    }
    if (path.startsWith('/state/')) {
      final key = path.substring('/state/'.length);
      if (request.method == 'PUT') {
        values[key] = request.body;
      } else {
        values.remove(key);
      }
      version++;
      return http.Response(jsonEncode({'version': version}), 200);
    }
    if (path == '/fotos') {
      return http.Response(jsonEncode({'path': '/fotos/abc.jpg'}), 200);
    }
    return http.Response('{}', 404);
  });
}

void main() {
  late FakeServer server;

  Future<(AppController, SilentDeviceNotifications)> phone() async {
    final device = MemoryStore();
    await device.write(AppController.syncUrlKey, 'http://192.168.1.50:8787');
    final notifications = SilentDeviceNotifications();
    final app = await AppController.load(
      store: device,
      deviceNotifications: notifications,
      syncClient: server.client(),
    );
    addTearDown(app.dispose);
    return (app, notifications);
  }

  setUp(() => server = FakeServer());

  test('artesano y turista en dos teléfonos ven lo mismo', () async {
    final (artisan, artisanDevice) = await phone();
    final (tourist, touristDevice) = await phone();
    expect(artisan.isSharedMode, isTrue);
    expect(tourist.isSharedMode, isTrue);

    // Teléfono 1: la artesana publica una pieza.
    expect(await artisan.signIn('elena@belaaktun.mx', 'Becal2026'), isNull);
    await artisan.upsertProduct(
      name: 'Sombrero de prueba',
      category: 'Sombreros',
      description: 'Para probar en dos teléfonos',
      technique: 'Tejido fino',
      price: 1500,
      madeToOrder: false,
      isActive: true,
      stock: 2,
      photos: const ['http://192.168.1.50:8787/fotos/abc.jpg'],
    );

    // Teléfono 2: un turista nuevo se registra y ve la pieza.
    expect(
      await tourist.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
        telefono: '9810000000',
      ),
      isNull,
    );
    await tourist.syncNow();
    final product = tourist.activeProducts.firstWhere(
      (item) => item.name == 'Sombrero de prueba',
    );
    expect(product.coverImage, 'http://192.168.1.50:8787/fotos/abc.jpg');

    // El turista compra.
    expect(await tourist.addToCart(product), isNull);
    final result = await tourist.checkout(
      name: 'Luis Uc',
      phone: '9810000000',
    );
    expect(result.error, isNull);

    // Al sincronizar, a la artesana le llega el aviso a su barra.
    artisanDevice.shown.clear();
    await artisan.syncNow();
    expect(artisan.pendingOrdersCount, 1);
    expect(artisanDevice.shown, contains('Nuevo pedido de Luis Uc'));

    // La artesana confirma y el turista recibe el aviso.
    final order = artisan.visibleOrders.single;
    expect(
      await artisan.changeOrderStatus(
        order.id,
        OrderStatus.accepted,
        pickupAt: DateTime.now().add(const Duration(days: 1)),
      ),
      isNull,
    );
    touristDevice.shown.clear();
    await tourist.syncNow();
    expect(tourist.visibleOrders.single.status, OrderStatus.accepted);
    expect(touristDevice.shown, contains('Tu pedido fue aceptado'));

    // También las visitas: el turista reserva y la artesana la ve.
    final service = tourist.activeServices.firstWhere(
      (item) => item.artisanId == 'art-01',
    );
    await tourist.requestBooking(
      service: service,
      date: DateTime.now().add(const Duration(days: 4)),
      timeSlot: '10:30',
      people: 2,
      name: 'Luis Uc',
      phone: '9810000000',
    );
    await artisan.syncNow();
    expect(
      artisan.pendingBookings.where((item) => item.touristName == 'Luis Uc'),
      hasLength(1),
    );
  });

  test('un cambio en un teléfono no borra lo que hizo el otro', () async {
    final (artisan, _) = await phone();
    final (tourist, _) = await phone();
    await artisan.signIn('elena@belaaktun.mx', 'Becal2026');
    await tourist.register(
      nombre: 'Luis Uc',
      email: 'luis@correo.mx',
      password: 'Clave1234',
    );
    await tourist.syncNow();

    // El turista reserva; la artesana, SIN haber sincronizado, edita su
    // catálogo. Antes de guardar, la app trae lo último del servidor.
    await tourist.requestBooking(
      service: tourist.activeServices.first,
      date: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '09:00',
      people: 1,
      name: 'Luis Uc',
      phone: '9810000000',
    );
    await artisan.setProductActive(artisan.myProducts.first.id, false);

    final saved = jsonDecode(server.values['bookings.v1']!) as List<dynamic>;
    expect(
      saved.where((item) => (item as Map)['touristName'] == 'Luis Uc'),
      hasLength(1),
    );
    await artisan.syncNow();
    expect(
      artisan.visibleBookings
          .where((item) => item.status == BookingStatus.requested)
          .any((item) => item.touristName == 'Luis Uc'),
      isTrue,
    );
  });

  test('sin servidor al abrir, usa los datos del teléfono y lo avisa', () async {
    server.down = true;
    final (app, _) = await phone();
    expect(app.isSharedMode, isFalse);
    expect(app.syncError, contains('192.168.1.50'));
  });

  test('si se cae la red, guarda el cambio y lo envía al volver', () async {
    final (artisan, _) = await phone();
    await artisan.signIn('elena@belaaktun.mx', 'Becal2026');
    server.down = true;
    await artisan.setProductActive(artisan.myProducts.first.id, false);
    expect(artisan.syncOnline, isFalse);
    server.down = false;
    await artisan.syncNow();
    expect(artisan.syncOnline, isTrue);
    final products = jsonDecode(server.values['products.v1']!) as List;
    expect((products.first as Map)['isActive'], isFalse);
  });

  test('normaliza la dirección del servidor', () {
    expect(normalizeSyncUrl('192.168.1.50'), 'http://192.168.1.50:8787');
    expect(normalizeSyncUrl('http://10.0.0.2:9000/'), 'http://10.0.0.2:9000');
    expect(normalizeSyncUrl('  '), isNull);
  });
}

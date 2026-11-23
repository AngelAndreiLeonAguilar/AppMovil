import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:bel_aaktun/data/services/device_notifications.dart';
import 'package:bel_aaktun/data/services/local_auth_api.dart';
import 'package:bel_aaktun/data/services/local_store.dart';
import 'package:bel_aaktun/domain/order.dart';
import 'package:bel_aaktun/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderRules', () {
    final created = DateTime(2026, 11, 1, 10);

    Order sample() => Order(
      id: 'od-1',
      folio: 'PD-1001',
      artisanId: 'art-01',
      buyerId: '3',
      buyerName: 'Luis',
      buyerPhone: '9810000000',
      items: const [
        OrderItem(
          productId: 'prod-01',
          productName: 'Sombrero',
          unitPrice: 500,
          quantity: 2,
        ),
      ],
      status: OrderStatus.requested,
      createdAt: created,
      updatedAt: created,
    );

    test('el taller acepta, programa la recogida, prepara y entrega', () {
      final now = DateTime(2026, 11, 1, 12);
      final pickup = DateTime(2026, 11, 3, 11);
      var order = OrderRules.apply(
        sample(),
        OrderStatus.accepted,
        by: UserRole.artisan,
        pickupAt: pickup,
        now: now,
      );
      expect(order.pickupAt, pickup);
      order = OrderRules.apply(
        order,
        OrderStatus.preparing,
        by: UserRole.artisan,
        now: now,
      );
      order = OrderRules.apply(
        order,
        OrderStatus.ready,
        by: UserRole.artisan,
        now: now,
      );
      order = OrderRules.apply(
        order,
        OrderStatus.delivered,
        by: UserRole.artisan,
        now: now,
      );
      expect(order.status, OrderStatus.delivered);
      expect(order.total, 1000);
      expect(order.history, hasLength(4));
    });

    test('no se puede marcar listo sin fecha de recogida', () {
      final accepted = OrderRules.apply(
        sample(),
        OrderStatus.accepted,
        by: UserRole.artisan,
      );
      expect(
        () => OrderRules.apply(accepted, OrderStatus.ready, by: UserRole.artisan),
        throwsA(isA<OrderRuleError>()),
      );
    });

    test('el comprador no puede aceptar su propio pedido', () {
      expect(
        () => OrderRules.apply(
          sample(),
          OrderStatus.accepted,
          by: UserRole.tourist,
        ),
        throwsA(isA<OrderRuleError>()),
      );
    });

    test('la recogida debe ser en el futuro', () {
      final now = DateTime(2026, 11, 2, 12);
      final accepted = OrderRules.apply(
        sample(),
        OrderStatus.accepted,
        by: UserRole.artisan,
        now: now,
      );
      expect(
        () => OrderRules.schedulePickup(
          accepted,
          DateTime(2026, 11, 1, 9),
          by: UserRole.artisan,
          now: now,
        ),
        throwsA(isA<OrderRuleError>()),
      );
    });

    test('lee pedidos de una sola pieza de versiones anteriores', () {
      final legacy = Order.fromJson({
        'id': 'od-old',
        'folio': 'PD-1000',
        'productId': 'prod-01',
        'productName': 'Sombrero',
        'artisanId': 'art-01',
        'buyerId': '3',
        'buyerName': 'Luis',
        'buyerPhone': '9810000000',
        'quantity': 2,
        'unitPrice': 300,
        'deliveryMethod': 'shipping',
        'status': 'confirmed',
        'createdAt': created.toIso8601String(),
        'updatedAt': created.toIso8601String(),
      });
      expect(legacy.status, OrderStatus.accepted);
      expect(legacy.items.single.quantity, 2);
      expect(legacy.total, 600);
    });
  });

  group('Carrito y pedidos con recogida', () {
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

    test('un carrito con dos talleres genera un pedido por taller', () async {
      final buyer = await open();
      await buyer.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      final priced = buyer.activeProducts
          .where((product) => product.price != null)
          .toList();
      final first = priced.first;
      final second = priced.firstWhere(
        (product) => product.artisanId != first.artisanId,
      );
      expect(await buyer.addToCart(first, quantity: 2), isNull);
      expect(await buyer.addToCart(second), isNull);
      expect(buyer.cartCount, 3);

      final result = await buyer.checkout(
        name: 'Luis Uc',
        phone: '981 000 0000',
      );
      expect(result.error, isNull);
      expect(result.orders, hasLength(2));
      expect(buyer.cartCount, 0);
      expect(
        buyer.visibleOrders.map((order) => order.artisanId).toSet(),
        {first.artisanId, second.artisanId},
      );
      expect(
        buyer.visibleOrders.every(
          (order) => order.status == OrderStatus.requested,
        ),
        isTrue,
      );
    });

    test('el carrito se conserva al volver a abrir la app', () async {
      final buyer = await open();
      await buyer.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      final product = buyer.activeProducts.firstWhere((p) => p.price != null);
      await buyer.addToCart(product);
      final reopened = await open();
      expect(reopened.cartQuantityOf(product.id), 1);
    });

    test('aceptar aparta existencias y avisa la fecha de recogida', () async {
      // El taller publica una pieza con 3 piezas.
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.upsertProduct(
        name: 'Sombrero fino',
        category: 'Sombreros',
        description: 'Tejido fino',
        technique: 'Tejido fino',
        price: 900,
        madeToOrder: false,
        isActive: true,
        stock: 3,
      );
      final product = shop.myProducts.firstWhere(
        (item) => item.name == 'Sombrero fino',
      );
      await shop.signOut();

      // El turista compra 2.
      final buyer = await open();
      await buyer.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      expect(await buyer.addToCart(product, quantity: 5), isNotNull);
      expect(await buyer.addToCart(product, quantity: 2), isNull);
      final result = await buyer.checkout(name: 'Luis Uc', phone: '9810000000');
      expect(result.orders.single.total, 1800);
      await buyer.signOut();

      // El taller recibe el aviso y acepta con fecha de recogida.
      final again = await open();
      device.shown.clear();
      await again.signIn('elena@belaaktun.mx', 'Becal2026');
      expect(device.shown, contains('Nuevo pedido de Luis Uc'));
      final order = again.visibleOrders.single;
      final pickup = DateTime.now().add(const Duration(days: 2));
      expect(
        await again.changeOrderStatus(
          order.id,
          OrderStatus.accepted,
          pickupAt: pickup,
          pickupNote: 'Pregunta por Doña Elena',
        ),
        isNull,
      );
      expect(again.productById(product.id)!.stock, 1);
      expect(again.visibleOrders.single.pickupAt, pickup);

      // Si el taller cancela, las piezas vuelven al inventario.
      expect(
        await again.changeOrderStatus(
          order.id,
          OrderStatus.cancelledByArtisan,
          note: 'Se dañó la pieza',
        ),
        isNull,
      );
      expect(again.productById(product.id)!.stock, 3);
    });

    test('las piezas de precio a consultar no entran al carrito', () async {
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      await shop.upsertProduct(
        name: 'Pieza única',
        category: 'Decoración',
        description: 'x',
        technique: 'y',
        price: null,
        madeToOrder: true,
        isActive: true,
      );
      final product = shop.myProducts.firstWhere((p) => p.name == 'Pieza única');
      await shop.signOut();
      final buyer = await open();
      await buyer.register(
        nombre: 'Luis Uc',
        email: 'luis@correo.mx',
        password: 'Clave1234',
      );
      expect(await buyer.addToCart(product), isNotNull);
    });

    test('el taller no puede comprar', () async {
      final shop = await open();
      await shop.signIn('elena@belaaktun.mx', 'Becal2026');
      expect(await shop.addToCart(shop.activeProducts.first), isNotNull);
    });
  });
}

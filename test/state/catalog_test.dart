import 'package:bel_aaktun/core/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppController> artisanController() async {
    final controller = await AppController.load(authApi: FakeAuthApi());
    await controller.signIn('elena@test.mx', 'Clave1234');
    return controller;
  }

  test('el taller crea una pieza y persiste', () async {
    final artisan = await artisanController();

    final error = await artisan.upsertProduct(
      name: 'Sombrero de prueba',
      category: 'Sombreros',
      description: 'Pieza nueva para probar el catálogo editable.',
      technique: 'Tejido fino',
      price: 1990,
      madeToOrder: false,
      isActive: true,
    );

    expect(error, isNull);
    final created = artisan.myProducts.firstWhere(
      (product) => product.name == 'Sombrero de prueba',
    );
    expect(created.price, 1990);
    expect(created.artisanId, 'art-01');

    final reloaded = await artisanController();
    expect(
      reloaded.myProducts.any((product) => product.id == created.id),
      isTrue,
    );
  });

  test('editar mantiene el id y actualiza los datos', () async {
    final artisan = await artisanController();
    final original = artisan.myProducts.first;

    final error = await artisan.upsertProduct(
      id: original.id,
      name: original.name,
      category: original.category,
      description: original.description,
      technique: original.technique,
      price: 9999,
      madeToOrder: original.madeToOrder,
      isActive: original.isActive,
    );

    expect(error, isNull);
    expect(artisan.productById(original.id)?.price, 9999);
    expect(artisan.myProducts.length, greaterThanOrEqualTo(1));
  });

  test('desactivar oculta la pieza al turista sin borrarla', () async {
    final artisan = await artisanController();
    final product = artisan.myProducts.first;

    await artisan.setProductActive(product.id, false);

    expect(artisan.activeProducts.any((item) => item.id == product.id), isFalse);
    expect(artisan.myProducts.any((item) => item.id == product.id), isTrue);
  });

  test('el turista no puede editar el catálogo', () async {
    final tourist = await AppController.load(authApi: FakeAuthApi());
    await tourist.signIn('turista@test.mx', 'Clave1234');

    final error = await tourist.upsertProduct(
      name: 'Intento',
      category: 'Sombreros',
      description: '',
      technique: '',
      price: 100,
      madeToOrder: false,
      isActive: true,
    );

    expect(error, isNotNull);
  });

  test('un taller no puede editar piezas de otro taller', () async {
    final artisan = await artisanController();
    final foreign = artisan.allProducts.firstWhere(
      (product) => product.artisanId != 'art-01',
    );

    final error = await artisan.upsertProduct(
      id: foreign.id,
      name: foreign.name,
      category: foreign.category,
      description: foreign.description,
      technique: foreign.technique,
      price: 123,
      madeToOrder: foreign.madeToOrder,
      isActive: true,
    );

    expect(error, isNotNull);
  });

  test('eliminar quita la pieza del catálogo', () async {
    final artisan = await artisanController();
    expect(
      await artisan.upsertProduct(
        name: 'Pieza temporal',
        category: 'Decoración',
        description: '',
        technique: '',
        price: 100,
        madeToOrder: false,
        isActive: true,
      ),
      isNull,
    );

    final temporal = artisan.myProducts.firstWhere(
      (product) => product.name == 'Pieza temporal',
    );
    expect(await artisan.deleteProduct(temporal.id), isNull);
    expect(artisan.productById(temporal.id), isNull);
  });

  test('una experiencia nueva aparece para reservar', () async {
    final artisan = await artisanController();

    final error = await artisan.upsertService(
      title: 'Taller de prueba',
      description: 'Experiencia creada desde el panel.',
      durationMinutes: 60,
      pricePerPerson: 300,
      depositPercent: 20,
      maxParticipants: 6,
      isActive: true,
    );

    expect(error, isNull);
    final created = artisan.myServices.firstWhere(
      (service) => service.title == 'Taller de prueba',
    );
    expect(artisan.activeServices.any((item) => item.id == created.id), isTrue);
  });

  test('valida el anticipo y el cupo de una experiencia', () async {
    final artisan = await artisanController();

    final badDeposit = await artisan.upsertService(
      title: 'Anticipo inválido',
      description: '',
      durationMinutes: 60,
      pricePerPerson: 300,
      depositPercent: 150,
      maxParticipants: 6,
      isActive: true,
    );
    expect(badDeposit, isNotNull);

    final badCapacity = await artisan.upsertService(
      title: 'Cupo inválido',
      description: '',
      durationMinutes: 60,
      pricePerPerson: 300,
      depositPercent: 30,
      maxParticipants: 0,
      isActive: true,
    );
    expect(badCapacity, isNotNull);
  });
}

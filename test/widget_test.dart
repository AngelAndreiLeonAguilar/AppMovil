import 'package:bel_aaktun/app.dart';
import 'package:bel_aaktun/core/widgets/bel_button.dart';
import 'package:bel_aaktun/core/widgets/bel_text_field.dart';
import 'package:bel_aaktun/features/account/account_screen.dart';
import 'package:bel_aaktun/features/catalog/widgets/product_card.dart';
import 'package:bel_aaktun/features/orders/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_api.dart';

/// Arranca la app con la API falsa.
Future<FakeAuthApi> pumpApp(WidgetTester tester) async {
  final api = FakeAuthApi();
  await tester.pumpWidget(BelAaktunApp(authApi: api));
  await tester.pumpAndSettle();
  return api;
}

/// Inicia sesión escribiendo correo y contraseña.
Future<FakeAuthApi> loginAs(
  WidgetTester tester,
  String email, {
  String password = 'Clave1234',
}) async {
  final api = await pumpApp(tester);
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
  return api;
}

/// Abre una pestaña del panel de administración (abre en Resumen).
Future<void> openAdminTab(WidgetTester tester, String label) async {
  final chip = find.text(label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Desplaza la lista hasta el campo con esa etiqueta y escribe en él.
Future<void> fillField(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.widgetWithText(BelTextField, label),
    matching: find.byType(TextFormField),
  );
  await tester.scrollUntilVisible(
    field,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Arranca en el inicio de sesión', (tester) async {
    await pumpApp(tester);

    expect(find.text('PLATAFORMA ARTESANAL'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Registrar mi taller'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('SERVIDOR'), findsOneWidget);
    expect(find.textContaining('/api/v1'), findsOneWidget);
  });

  testWidgets('Registro de turista crea la cuenta y entra', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nueva Turista');
    await tester.enterText(fields.at(1), 'nueva@test.mx');
    await tester.enterText(fields.at(2), '+52 981 000 0000');
    await tester.enterText(fields.at(3), 'Clave1234');
    await tester.enterText(fields.at(4), 'Clave1234');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BelButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('BEL·AAKTUN'), findsOneWidget);
  });

  testWidgets('El turista entra y navega al catálogo', (tester) async {
    await loginAs(tester, 'turista@test.mx');

    expect(find.text('BEL·AAKTUN'), findsOneWidget);
    expect(find.text('El arte de tejer\nla palma'), findsOneWidget);

    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar pieza, técnica o artesano'), findsOneWidget);
  });

  testWidgets('Credenciales incorrectas muestran el error', (tester) async {
    await loginAs(tester, 'turista@test.mx', password: 'Incorrecta1');

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Desliza al costado para cambiar de pestaña', (tester) async {
    await loginAs(tester, 'turista@test.mx');

    await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Buscar pieza, técnica o artesano'), findsOneWidget);
  });

  testWidgets('Mis reservas invita a crear la primera visita', (tester) async {
    await loginAs(tester, 'turista@test.mx');

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva reserva'), findsOneWidget);
    expect(find.text('Aún no tienes visitas'), findsOneWidget);
  });

  testWidgets('El turista solicita una reserva y queda registrada', (
    tester,
  ) async {
    await loginAs(tester, 'turista@test.mx');

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva reserva'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.at(0), 'Ana Prueba');
    await tester.enterText(fields.at(1), '+52 981 111 1111');
    await tester.pumpAndSettle();

    final submit = find.text('Solicitar reserva');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(find.textContaining('todavía no cobra en línea'), findsWidgets);
  });

  testWidgets('Comprar con carrito y recogida en el taller', (tester) async {
    await loginAs(tester, 'turista@test.mx');

    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCard).first);
    await tester.pumpAndSettle();

    // El botón principal agrega al carrito; no pide reservar una visita.
    await tester.tap(find.widgetWithText(BelButton, 'Agregar al carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CartButton).first);
    await tester.pumpAndSettle();

    // El carrito no pide dirección de envío: se recoge en el taller.
    expect(find.text('Mi carrito'), findsOneWidget);
    expect(find.textContaining('Recoger en el taller'), findsWidgets);
    expect(find.textContaining('Dirección de envío'), findsNothing);
    expect(find.textContaining('No hacemos envíos'), findsOneWidget);

    await fillField(tester, 'TELÉFONO O WHATSAPP', '981 123 4567');
    await tester.tap(find.textContaining('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(find.text('¡Pedido enviado!'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Pendiente de aceptación'), findsWidgets);
  });

  testWidgets('El turista solicita verificar su taller', (tester) async {
    await loginAs(tester, 'turista@test.mx');

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AccountAvatarButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Tienes un taller artesanal?'));
    await tester.pumpAndSettle();

    expect(find.text('Verificar taller'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Cueva Nueva');
    await tester.enterText(
      fields.at(1),
      'Taller familiar de tejido de jipi con visitas guiadas.',
    );
    await fillField(tester, 'TELÉFONO O WHATSAPP', '981 123 4567');

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final submit = find.text('Enviar solicitud');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Tu solicitud'), findsOneWidget);
    expect(find.text('Cueva Nueva'), findsOneWidget);
  });

  testWidgets('La artesana entra a su panel', (tester) async {
    await loginAs(tester, 'elena@test.mx');

    expect(find.text('PANEL DEL TALLER'), findsOneWidget);
    expect(find.text('Por responder'), findsOneWidget);
  });

  testWidgets('La artesana agrega una pieza a su catálogo', (tester) async {
    await loginAs(tester, 'elena@test.mx');

    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();

    expect(find.text('Mi catálogo'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva pieza'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Pieza de prueba');
    await fillField(tester, 'PRECIO', '850');

    final save = find.text('Publicar pieza');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Pieza de prueba'), findsOneWidget);
  });

  testWidgets('El administrador ve la solicitud pendiente', (tester) async {
    await loginAs(tester, 'admin@test.mx');

    expect(find.text('ADMINISTRACIÓN GENERAL'), findsOneWidget);
    expect(find.text('Solicitudes pendientes'), findsOneWidget);
    await openAdminTab(tester, 'Solicitudes');
    expect(find.text('Cueva en trámite'), findsOneWidget);
    expect(find.text('Aprobar'), findsOneWidget);
  });

  testWidgets('El administrador aprueba un taller', (tester) async {
    final api = await loginAs(tester, 'admin@test.mx');
    await openAdminTab(tester, 'Solicitudes');

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();

    expect(find.text('Taller aprobado.'), findsOneWidget);

    final approved = await api.login(
      email: 'pendiente@test.mx',
      password: 'Clave1234',
    );
    expect(approved.user.role.name, 'artisan');
  });

  testWidgets('El taller pendiente ve su estado y puede explorar', (
    tester,
  ) async {
    await loginAs(tester, 'pendiente@test.mx');

    expect(find.text('Tu solicitud'), findsOneWidget);
    expect(find.text('Cueva en trámite'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);

    await tester.tap(find.text('Explorar mientras tanto'));
    await tester.pumpAndSettle();

    expect(find.text('BEL·AAKTUN'), findsOneWidget);
  });
}

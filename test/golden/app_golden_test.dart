import 'dart:io';

import 'package:bel_aaktun/app.dart';
import 'package:bel_aaktun/features/catalog/widgets/product_card.dart';
import 'package:bel_aaktun/features/orders/cart_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_api.dart';

/// Carga las tipografías reales para las capturas de referencia.
Future<void> _loadFonts() async {
  final serif = FontLoader('PlayfairDisplay')
    ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay-SemiBold.ttf'));
  final garamond = FontLoader('CormorantGaramond')
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-Light.ttf'))
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-Italic.ttf'));
  final lato = FontLoader('Lato')
    ..addFont(rootBundle.load('assets/fonts/Lato-Light.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Lato-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Lato-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Lato-Black.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Lato-Italic.ttf'));

  // Íconos de Material: sin esto se dibujan como cuadros vacíos.
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));

  await Future.wait([serif.load(), garamond.load(), lato.load(), icons.load()]);
}

/// Comparador que tolera diferencias mínimas.
///
/// Los datos de demostración usan fechas relativas a hoy ("11 nov · 10:30"),
/// así que unas cuantas letras cambian cada día. Un cambio real de diseño
/// mueve mucho más del 1 % de los píxeles.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  static const _tolerance = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  setUpAll(() {
    final current = goldenFileComparator;
    if (current is LocalFileComparator) {
      goldenFileComparator = _TolerantComparator(
        Uri.parse('${current.basedir}app_golden_test.dart'),
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              Directory.systemTemp.createTempSync('bel_aaktun_test').path,
        );
  });

  setUpAll(_loadFonts);

  Future<void> pumpApp(
    WidgetTester tester, {
    String? loginAs,
    Size? size,
  }) async {
    final logical = size ?? const Size(390, 844);
    tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(BelAaktunApp(authApi: FakeAuthApi()));
    await tester.pumpAndSettle();

    if (loginAs != null) {
      await tester.enterText(find.byType(TextFormField).at(0), loginAs);
      await tester.enterText(find.byType(TextFormField).at(1), 'Clave1234');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('captura: inicio de sesión', (tester) async {
    await pumpApp(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/00_login.png'),
    );
  });

  testWidgets('captura: inicio', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_inicio_claro.png'),
    );
  });

  testWidgets('captura: catálogo', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_catalogo.png'),
    );
  });

  testWidgets('captura: mapa', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_mapa.png'),
    );
  });

  testWidgets('captura: artesanos', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_artesanos.png'),
    );
  });

  testWidgets('captura: mis reservas', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05_reservas.png'),
    );
  });

  testWidgets('captura: inicio en modo oscuro', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06_inicio_oscuro.png'),
    );
  });

  testWidgets('captura: detalle de pieza', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -720),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCard).first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/07_pieza.png'),
    );
  });

  testWidgets('captura: perfil de artesano', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doña Elena Chan'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08_artesano.png'),
    );
  });

  testWidgets('captura: contacto', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/09_contacto.png'),
    );
  });

  testWidgets('captura: panel del artesano', (tester) async {
    await pumpApp(tester, loginAs: 'elena@test.mx');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/10_panel_artesano.png'),
    );
  });

  testWidgets('captura: reservaciones del artesano', (tester) async {
    await pumpApp(tester, loginAs: 'elena@test.mx');
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/11_reservas_artesano.png'),
    );
  });

  testWidgets('captura: catálogo del taller', (tester) async {
    await pumpApp(tester, loginAs: 'elena@test.mx');
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/12_catalogo_taller.png'),
    );
  });

  testWidgets('captura: nueva pieza', (tester) async {
    await pumpApp(tester, loginAs: 'elena@test.mx');
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/13_form_pieza.png'),
    );
  });

  testWidgets('captura: estado de solicitud', (tester) async {
    await pumpApp(tester, loginAs: 'pendiente@test.mx');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/14_estado_solicitud.png'),
    );
  });

  testWidgets('captura: panel de administración', (tester) async {
    await pumpApp(tester, loginAs: 'admin@test.mx');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/15_admin.png'),
    );
  });

  testWidgets('captura: carrito', (tester) async {
    await pumpApp(tester, loginAs: 'turista@test.mx');
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProductCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CartButton).first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/16_carrito.png'),
    );
  });

  testWidgets('sin desbordes en pantalla de 320 px', (tester) async {
    await pumpApp(
      tester,
      loginAs: 'turista@test.mx',
      size: const Size(320, 640),
    );

    for (final label in ['Catálogo', 'Mapa', 'Actividad']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

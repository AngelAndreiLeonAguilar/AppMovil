import 'dart:async';

import 'package:bel_aaktun/core/config/app_config.dart';

/// Las pruebas automáticas trabajan con los datos de ejemplo (talleres,
/// piezas, reservas y cuentas de prueba). La app del piloto arranca vacía.
///
/// La regla de mensualidad se apaga aquí para que las pruebas de compras y
/// reservas no dependan de ella; `test/state/subscription_test.dart` la
/// enciende para probarla.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.seedSampleData = true;
  AppConfig.enforceSubscription = false;
  await testMain();
}

import 'dart:async';

import 'package:bel_aaktun/core/config/app_config.dart';

/// Las pruebas automáticas trabajan con los datos de ejemplo (talleres,
/// piezas, reservas y cuentas de prueba). La app del piloto arranca vacía.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.seedSampleData = true;
  await testMain();
}

/// Configuración de la aplicación.
///
/// Todo lo que depende del negocio y no del diseño vive aquí para que puedas
/// sustituirlo por datos reales sin tocar la interfaz.
library;

import 'package:flutter/foundation.dart';

import '../../domain/user.dart';

/// Cuenta que se crea al instalar la app en modo local.
class DemoAccount {
  const DemoAccount({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.artisanId,
  });

  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? artisanId;
}

abstract final class AppConfig {
  static const String appName = 'Bel-Aaktun';
  static const String tagline = 'Cuevas artesanales de Bécal';

  // ---------------------------------------------------------------------------
  // Modo de datos
  //
  // Sin servidor, la app guarda cuentas, catálogo, reservas y fotos en el
  // propio teléfono. En cuanto exista el backend, compila con
  // `--dart-define=API_BASE_URL=https://api.tudominio.mx/api/v1` y la
  // autenticación volverá a la API real.
  // ---------------------------------------------------------------------------

  /// `true` mientras no se haya definido `API_BASE_URL` al compilar.
  static bool get useLocalBackend =>
      const String.fromEnvironment('API_BASE_URL').isEmpty;

  /// En modo local, las solicitudes de taller se aprueban al instante para que
  /// los artesanos de prueba puedan usar su panel sin esperar a un
  /// administrador. Ponlo en `false` para revisar cada solicitud a mano desde
  /// la cuenta de administración.
  static const bool autoApproveArtisans = true;

  // ---------------------------------------------------------------------------
  // Mensualidad de los talleres
  //
  // Con la mensualidad al día el taller aparece activo y recibe pedidos y
  // reservas. Sin ella se muestra como «fuera de servicio». La app no cobra en
  // línea: el taller paga por transferencia o en efectivo, registra su
  // referencia y la administración confirma el pago.
  // ---------------------------------------------------------------------------

  /// `false` desactiva la regla (las pruebas antiguas lo apagan).
  static bool enforceSubscription = true;

  /// Mensualidad por taller, en pesos con IVA incluido.
  static const int monthlyFee = 199;

  /// Días que cubre cada pago confirmado.
  static const int subscriptionDays = 30;

  /// Cómo pagar (se muestra al taller). Ajusta con los datos reales.
  static const String subscriptionPaymentInstructions =
      'Paga por transferencia a la cuenta de Bel-Aaktun que te comparte la '
      'administración, o en efectivo con el equipo durante su visita.';

  /// Muestra dos talleres de ejemplo (uno activo y otro fuera de servicio)
  /// para enseñar cómo funciona la app. No reciben pedidos reales.
  static const bool showShowcaseArtisans = true;

  /// Datos de ejemplo (talleres, piezas, experiencias, reservas y las cuentas
  /// de artesana y turista de prueba).
  ///
  /// `false` en la versión del piloto: la app arranca vacía para que se
  /// registren los talleres y usuarios reales, y al actualizar se borran los
  /// datos de ejemplo que hubiera de versiones anteriores. Las pruebas
  /// automáticas lo activan en `test/flutter_test_config.dart`.
  static bool seedSampleData = false;

  /// Crea las cuentas iniciales la primera vez que se abre la app. Siempre
  /// incluye la administración, que aprueba talleres y modera el catálogo.
  static const bool seedDemoAccounts = true;

  /// Contraseña de la administración. **No se guarda en el código**: se define
  /// al compilar con `--dart-define=ADMIN_PASSWORD=...`. Sin ella no se crea
  /// la cuenta de administración. Al abrir la app, la cuenta toma siempre esta
  /// contraseña.
  static const String _adminPasswordFromBuild = String.fromEnvironment(
    'ADMIN_PASSWORD',
  );

  /// Contraseña para las cuentas de prueba (solo pruebas automáticas, se fija
  /// en `test/flutter_test_config.dart`).
  static String testAccountsPassword = '';

  static String get adminPassword => _adminPasswordFromBuild.isNotEmpty
      ? _adminPasswordFromBuild
      : testAccountsPassword;

  /// Cuenta de administración de la plataforma.
  static const String adminEmail = 'admin@belaaktun.mx';

  static DemoAccount get adminAccount => DemoAccount(
    name: 'Administración Bel-Aaktun',
    email: adminEmail,
    password: adminPassword,
    role: UserRole.admin,
  );

  /// Cuentas que se crean al instalar: la administración y, solo con datos de
  /// ejemplo, la artesana y el turista de prueba.
  static List<DemoAccount> get demoAccounts => [
    adminAccount,
    if (seedSampleData) ...sampleAccounts,
  ];

  /// Correos de las cuentas de ejemplo (para limpiarlas al actualizar).
  static Set<String> get sampleAccountEmails =>
      {for (final account in sampleAccounts) account.email};

  /// Cuentas de prueba (solo con `seedSampleData`).
  static List<DemoAccount> get sampleAccounts => [
    DemoAccount(
      name: 'Doña Elena Chan',
      email: 'elena@belaaktun.mx',
      password: testAccountsPassword,
      role: UserRole.artisan,
      artisanId: 'art-01',
    ),
    DemoAccount(
      name: 'Turista demo',
      email: 'turista@belaaktun.mx',
      password: testAccountsPassword,
      role: UserRole.tourist,
    ),
  ];

  /// URL base de la API.
  ///
  /// Se puede sobrescribir al compilar:
  /// `flutter run --dart-define=API_BASE_URL=https://api.tudominio.mx/api/v1`
  ///
  /// Por defecto apunta al backend local: `10.0.2.2` desde el emulador de
  /// Android y `127.0.0.1` en escritorio, iOS simulator y web.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001/api/v1';
    }
    return 'http://127.0.0.1:5001/api/v1';
  }

  /// Identificador usado como User-Agent al pedir teselas del mapa.
  /// Debe coincidir con `applicationId` de Android / `PRODUCT_BUNDLE_IDENTIFIER`.
  static const String packageName = 'com.belaaktun.bel_aaktun';

  /// Muestra la etiqueta "Contenido demo" en catálogo y contacto.
  /// Cámbialo a `false` cuando conectes el contenido real.
  static const bool showDemoBadges = true;

  // ---------------------------------------------------------------------------
  // Mapa
  //
  // Por defecto se usan teselas de OpenStreetMap: gratis, sin API key y sin
  // cuenta de facturación. Para producción con tráfico alto conviene cambiar
  // [mapTileUrl] por un proveedor con SLA (MapTiler, Stadia, Thunderforest o
  // tus propias teselas) y revisar [mapAttribution].
  // ---------------------------------------------------------------------------

  /// Centro del pueblo de Bécal, Calkiní, Campeche.
  static const double mapCenterLat = 20.4426;
  static const double mapCenterLng = -90.0282;
  static const double mapInitialZoom = 14.5;

  /// Plantilla de teselas. `{z}/{x}/{y}` y `{r}` (retina) los resuelve
  /// flutter_map. Ejemplo MapTiler:
  /// `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=TU_KEY`
  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Atribución obligatoria del proveedor de teselas.
  static const String mapAttribution = '© OpenStreetMap';

  // ---------------------------------------------------------------------------
  // Contacto — TODO: sustituir por los datos reales de Bel-Aaktun.
  // ---------------------------------------------------------------------------
  static const String phone = '+52 981 000 0000';
  static const String whatsapp = '+52 981 000 0000';
  static const String email = 'hola@belaaktun.mx';
  static const String address = 'Bécal, Campeche, México';
  static const String schedule = 'Lunes a sábado · 9:00 a 18:00';
  static const String instagram = '@belaaktun';
  static const String facebook = 'Bel-Aaktun';

  // ---------------------------------------------------------------------------
  // Reservas
  // ---------------------------------------------------------------------------
  static const List<String> bookingTimeSlots = [
    '09:00',
    '10:30',
    '12:00',
    '16:00',
    '17:30',
  ];
  static const int maxPeoplePerBooking = 12;
  static const int bookingHorizonDays = 21;
}

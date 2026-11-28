import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/demo_content.dart';
import '../../data/demo_seed.dart';
import '../../data/models.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_api.dart';
import '../../data/services/device_notifications.dart';
import '../../data/services/local_auth_api.dart';
import '../../data/services/local_store.dart';
import '../../data/services/photo_service.dart';
import '../../data/services/sync_store.dart';
import '../../domain/app_notification.dart';
import '../../domain/artisan_application.dart';
import '../../domain/booking.dart';
import '../../domain/booking_rules.dart';
import '../../domain/finance.dart';
import '../../domain/money.dart';
import '../../domain/order.dart';
import '../../domain/user.dart';
import '../../domain/user_account.dart';
import '../config/app_config.dart';

/// Estado global de la aplicación: sesión, reservaciones y notificaciones.
///
/// La autenticación y la verificación de talleres viven en la API; las
/// reservaciones y el catálogo siguen siendo locales mientras se migran.
class AppController extends ChangeNotifier {
  AppController._(
    this._store,
    this._repository,
    this._catalogRepository,
    this._authApi,
    this._device, {
    required this._apiBaseUrl,
    required this._injectedApi,
    required this._localMode,
  });

  static const _notificationsKey = 'notifications.v1';
  static const _accessKey = 'auth.access';
  static const _refreshKey = 'auth.refresh';
  static const _userKey = 'auth.user';
  static const _apiKey = 'api.baseUrl';
  static const _artisansKey = 'artisans.v1';
  static const _ordersKey = 'orders.v1';
  static const _ledgerKey = 'ledger.v1';
  static const _commissionKey = 'finance.settings.v1';
  static const _avatarsKey = 'avatars.v1';
  static const _permissionAskedKey = 'notifications.asked';
  static const _deviceEnabledKey = 'notifications.device';

  /// Dirección del servidor de pruebas guardada en este teléfono.
  static const syncUrlKey = 'sync.url';

  final LocalStore _store;
  SyncStore? _sync;
  String? _syncError;
  Timer? _pollTimer;
  bool _polling = false;
  int _loadedVersion = -1;

  /// La app lo usa para reiniciarse al cambiar de servidor.
  VoidCallback? onRestartRequested;
  final BookingRepository _repository;
  final CatalogRepository _catalogRepository;

  AuthApi _authApi;
  final DeviceNotifications _device;
  final bool _injectedApi;
  final bool _localMode;
  String _apiBaseUrl;
  StreamSubscription<String?>? _tapSubscription;
  final StreamController<String?> _openRequests = StreamController.broadcast();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  ArtisanApplication? _application;
  List<Booking> _bookings = [];
  List<AppNotification> _notifications = [];
  List<Product> _products = [];
  List<Experience> _services = [];
  List<Artisan> _artisans = [];
  List<Order> _orders = [];
  List<CartLine> _cart = [];
  List<LedgerEntry> _ledger = [];
  CommissionSettings _commission = const CommissionSettings();
  Map<String, String> _avatars = {};
  bool _ready = false;
  bool _deviceNotificationsEnabled = true;

  /// Carga la app: sesión, datos y semilla de demostración si está vacío.
  ///
  /// Sin [authApi] y sin `API_BASE_URL`, todo funciona dentro del teléfono
  /// ([LocalAuthApi]). En pruebas se inyecta una API falsa y las
  /// notificaciones del sistema quedan en silencio.
  static Future<AppController> load({
    AuthApi? authApi,
    DeviceNotifications? deviceNotifications,
    LocalStore? store,
    http.Client? syncClient,
  }) async {
    final deviceStore = store ?? await LocalStore.open();
    var localStore = deviceStore;

    // Servidor de pruebas en la red local (dos o más teléfonos).
    SyncStore? sync;
    String? syncError;
    final savedSync = deviceStore.read(syncUrlKey) ?? '';
    const definedSync = String.fromEnvironment('SYNC_URL');
    final syncUrl = savedSync.isNotEmpty ? savedSync : definedSync;
    if (authApi == null && AppConfig.useLocalBackend && syncUrl.isNotEmpty) {
      final candidate = SyncStore(deviceStore, syncUrl, client: syncClient);
      await candidate.refresh();
      if (candidate.isOnline) {
        sync = candidate;
        localStore = candidate;
        PhotoService.uploader = candidate.uploadPhoto;
      } else {
        syncError =
            'No se pudo conectar con el servidor de pruebas '
            '(${candidate.baseUrl}). Mientras tanto se usan los datos de este '
            'teléfono.';
      }
    }
    final storedUrl = localStore.read(_apiKey);
    final baseUrl = storedUrl != null && storedUrl.isNotEmpty
        ? storedUrl
        : AppConfig.apiBaseUrl;
    final localMode = authApi == null && AppConfig.useLocalBackend;
    final api =
        authApi ??
        (localMode
            ? LocalAuthApi(localStore)
            : HttpAuthApi(client: ApiClient(baseUrl: baseUrl)));
    final device =
        deviceNotifications ??
        (authApi != null
            ? SilentDeviceNotifications()
            : LocalDeviceNotifications());
    final controller = AppController._(
      localStore,
      LocalBookingRepository(localStore),
      LocalCatalogRepository(localStore),
      api,
      device,
      apiBaseUrl: baseUrl,
      injectedApi: authApi != null,
      localMode: localMode,
    );
    controller
      .._sync = sync
      .._syncLocal = sync == null ? null : deviceStore
      .._syncError = syncError;
    await device.init();
    controller._tapSubscription = device.taps.listen(
      controller._openRequests.add,
    );
    try {
      await controller._restore();
    } catch (_) {
      // Si algo falla al leer datos viejos, la app debe abrir igual.
      controller._ready = true;
      controller.notifyListeners();
    }
    if (sync != null) {
      controller._loadedVersion = sync.version;
      controller._pollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => controller._poll(),
      );
    }
    return controller;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_sync != null) PhotoService.uploader = null;
    _tapSubscription?.cancel();
    _openRequests.close();
    super.dispose();
  }

  /// URL de la API que está usando la app.
  String get apiBaseUrl => _apiBaseUrl;

  /// `true` cuando los datos se comparten por el servidor de pruebas.
  bool get isSharedMode => _sync != null;

  /// Dirección del servidor de pruebas en uso.
  String? get syncUrl => _sync?.baseUrl;

  /// `false` si se perdió la conexión con el servidor de pruebas.
  bool get syncOnline => _sync?.isOnline ?? false;

  /// Error al conectar con el servidor de pruebas al abrir la app.
  String? get syncError => _syncError;

  /// Guarda (o quita, con `null`) el servidor de pruebas y reinicia la app.
  /// Devuelve `null` si todo bien o el mensaje de error.
  Future<String?> setSyncServer(String? url) async {
    final device = _deviceStore;
    if (url == null || url.trim().isEmpty) {
      await device.delete(syncUrlKey);
    } else {
      final normalized = normalizeSyncUrl(url);
      final error = await SyncStore.check(url);
      if (error != null || normalized == null) return error;
      await device.write(syncUrlKey, normalized);
    }
    onRestartRequested?.call();
    return null;
  }

  LocalStore get _deviceStore => _sync == null ? _store : _syncLocal!;
  LocalStore? _syncLocal;

  /// Trae cambios de otros teléfonos (cada pocos segundos).
  Future<void> _poll() async {
    final sync = _sync;
    if (sync == null || _polling) return;
    _polling = true;
    try {
      final wasOnline = sync.isOnline;
      await sync.refresh();
      if (sync.version != _loadedVersion) {
        await _reloadData();
        notifyListeners();
        await _deliverPending();
        await _syncReminders();
      } else if (wasOnline != sync.isOnline) {
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  /// Sincroniza en este momento (pruebas y botón de "actualizar").
  Future<void> syncNow() => _poll();

  /// Antes de cambiar algo, toma lo último del servidor para no pisar
  /// cambios hechos en otro teléfono.
  Future<void> _pull() async {
    final sync = _sync;
    if (sync == null) return;
    await sync.refresh();
    if (sync.version != _loadedVersion) await _reloadData();
  }

  Future<void> _reloadData() async {
    _bookings = await _repository.load();
    _notifications = _decodeNotifications();
    _artisans = _decodeArtisans();
    _avatars = _decodeAvatars();
    _orders = _decodeOrders();
    _ledger = _decodeLedger();
    _commission = _decodeCommission();
    final catalog = await _catalogRepository.load();
    _products = catalog.products;
    _services = catalog.services;
    _loadedVersion = _sync?.version ?? _loadedVersion;
  }

  /// `true` cuando las cuentas y los datos viven solo en este teléfono.
  bool get isLocalMode => _localMode;

  /// En pruebas y en modo local no se permite cambiar la URL.
  bool get canChangeApiBaseUrl => !_injectedApi && !_localMode;

  /// Se emite cuando el usuario toca una notificación del sistema
  /// (payload = id de la reservación, si lo hay).
  Stream<String?> get notificationOpens => _openRequests.stream;

  /// Comprueba que el servidor responda. `null` si todo bien.
  Future<String?> testConnection() async {
    try {
      await _authApi.ping();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Prueba una URL antes de guardarla.
  Future<String?> testConnectionAt(String value) async {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return 'Escribe una URL válida, por ejemplo http://192.168.1.50:5001/api/v1';
    }
    try {
      await HttpAuthApi(client: ApiClient(baseUrl: normalized)).ping();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Guarda una URL de API distinta (por ejemplo, la IP del equipo en la red
  /// local cuando se prueba desde un teléfono físico).
  Future<String?> setApiBaseUrl(String value) async {
    if (_injectedApi) return null;
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return 'Escribe una URL válida, por ejemplo http://192.168.1.50:5001/api/v1';
    }
    _apiBaseUrl = normalized;
    _authApi = HttpAuthApi(client: ApiClient(baseUrl: normalized));
    await _store.write(_apiKey, normalized);
    notifyListeners();
    return null;
  }

  bool get isReady => _ready;

  User? get user => _user;

  bool get isSignedIn => _user != null;

  bool get isArtisan => _user?.role == UserRole.artisan;

  /// Ficha del taller del artesano autenticado.
  Artisan? get artisan {
    final artisanId = _user?.artisanId;
    if (artisanId == null) return null;
    return artisanById(artisanId);
  }

  /// Talleres visibles para el turista: primero los activos y después los
  /// que están fuera de servicio.
  List<Artisan> get artisans {
    final visible = [
      for (final artisan in _artisans)
        if (artisan.isPublished) artisan,
    ];
    final now = DateTime.now();
    final active = [
      for (final artisan in visible)
        if (_inService(artisan, now)) artisan,
    ];
    return [
      ...active,
      for (final artisan in visible)
        if (!active.contains(artisan)) artisan,
    ];
  }

  // ---------------------------------------------------------------------------
  // Mensualidad del taller
  // ---------------------------------------------------------------------------

  bool _inService(Artisan artisan, DateTime now) =>
      !AppConfig.enforceSubscription || artisan.isInServiceAt(now);

  /// `true` si el taller tiene su mensualidad al día (o la regla está apagada).
  bool isArtisanInService(String artisanId, {DateTime? now}) {
    final artisan = artisanById(artisanId);
    if (artisan == null) return !AppConfig.enforceSubscription;
    return _inService(artisan, now ?? DateTime.now());
  }

  /// `null` si el taller puede recibir pedidos y reservas; si no, el motivo.
  String? artisanServiceBlock(String artisanId, {DateTime? now}) {
    final artisan = artisanById(artisanId);
    if (artisan != null && artisan.isShowcase) {
      return 'Este es un taller de ejemplo: los talleres reales sí reciben '
          'pedidos y reservas.';
    }
    if (!isArtisanInService(artisanId, now: now)) {
      return 'Este taller está fuera de servicio por ahora: no recibe pedidos '
          'ni reservas hasta renovar su mensualidad.';
    }
    return null;
  }

  /// Talleres con un pago de mensualidad esperando confirmación.
  int get pendingSubscriptionCount =>
      _artisans.where((artisan) => artisan.hasPendingPayment).length;

  /// Todos los talleres, para el panel de administración.
  List<Artisan> get allArtisans => List.unmodifiable(_artisans);

  /// El taller avisa que pagó su mensualidad (transferencia o efectivo).
  Future<String?> reportSubscriptionPayment(String reference) async {
    await _pull();
    final current = _user;
    final artisanId = current?.artisanId;
    if (current == null ||
        current.role != UserRole.artisan ||
        artisanId == null) {
      return 'Solo el taller puede registrar su pago.';
    }
    final clean = reference.trim();
    if (clean.length < 3) {
      return 'Escribe la referencia, el folio o cómo pagaste.';
    }
    final index = _artisans.indexWhere((item) => item.id == artisanId);
    if (index < 0) return 'Completa primero el perfil de tu taller.';
    _artisans[index] = _artisans[index].copyWith(
      subscriptionPendingRef: clean,
      subscriptionPendingAt: DateTime.now(),
    );
    await _persistArtisans();
    notifyListeners();
    return null;
  }

  /// La administración confirma el pago: el taller queda activo
  /// [AppConfig.subscriptionDays] días más.
  Future<String?> adminConfirmSubscription(
    String artisanId, {
    DateTime? now,
  }) async {
    await _pull();
    if (!isAdmin) return 'Solo la administración puede confirmar pagos.';
    final index = _artisans.indexWhere((item) => item.id == artisanId);
    if (index < 0) return 'No se encontró ese taller.';
    final artisan = _artisans[index];
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final until = artisan.subscriptionUntil;
    final base = until != null && !until.isBefore(today) ? until : today;
    final next = DateTime(
      base.year,
      base.month,
      base.day,
    ).add(const Duration(days: AppConfig.subscriptionDays));
    _artisans[index] = artisan.copyWith(
      subscriptionUntil: next,
      clearPendingPayment: true,
    );
    _addNotification(
      userId: _artisanUserId(artisanId),
      type: AppNotificationType.subscription,
      title: 'Tu taller está activo',
      body:
          'Recibimos tu mensualidad. Apareces activo hasta el '
          '${_shortDate(next)}.',
    );
    await _persistArtisans();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    return null;
  }

  /// La administración rechaza un pago avisado (no se encontró, monto
  /// incorrecto…).
  Future<String?> adminRejectSubscription(
    String artisanId, {
    String? reason,
  }) async {
    await _pull();
    if (!isAdmin) return 'Solo la administración puede revisar pagos.';
    final index = _artisans.indexWhere((item) => item.id == artisanId);
    if (index < 0) return 'No se encontró ese taller.';
    _artisans[index] = _artisans[index].copyWith(clearPendingPayment: true);
    final clean = (reason ?? '').trim();
    _addNotification(
      userId: _artisanUserId(artisanId),
      type: AppNotificationType.subscription,
      title: 'No pudimos confirmar tu pago',
      body: clean.isEmpty
          ? 'Revisa tu referencia y vuelve a registrarla.'
          : 'Motivo: $clean',
    );
    await _persistArtisans();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    return null;
  }

  /// La administración pone un taller fuera de servicio de inmediato.
  Future<String?> adminSetOutOfService(String artisanId) async {
    await _pull();
    if (!isAdmin) return 'Solo la administración puede hacer este cambio.';
    final index = _artisans.indexWhere((item) => item.id == artisanId);
    if (index < 0) return 'No se encontró ese taller.';
    _artisans[index] = _artisans[index].copyWith(
      clearSubscription: true,
      clearPendingPayment: true,
    );
    _addNotification(
      userId: _artisanUserId(artisanId),
      type: AppNotificationType.subscription,
      title: 'Tu taller aparece fuera de servicio',
      body: 'Renueva tu mensualidad para volver a recibir pedidos y reservas.',
    );
    await _persistArtisans();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    return null;
  }

  /// Talleres de muestra que trae la app (no son cuentas reales).
  bool isSampleArtisan(String id) =>
      DemoContent.sampleArtisans.any((artisan) => artisan.id == id) ||
      (artisanById(id)?.isShowcase ?? false);

  Artisan? artisanById(String id) {
    for (final artisan in _artisans) {
      if (artisan.id == id) return artisan;
    }
    return null;
  }

  /// Foto de perfil de la cuenta actual (la del taller si es artesano).
  String? get myAvatar {
    final current = _user;
    if (current == null) return null;
    if (current.role == UserRole.artisan) return artisan?.imagePath;
    return _avatars[current.id];
  }

  /// Qué le falta al taller para verse completo ante los turistas.
  List<ProfileTask> get profileTasks {
    final shop = artisan;
    if (shop == null) return const [];
    final products = myProducts;
    final services = myServices;
    return [
      ProfileTask(
        ProfileTaskKind.photo,
        'Sube una foto de perfil',
        shop.imagePath != null,
      ),
      ProfileTask(
        ProfileTaskKind.cover,
        'Agrega una foto de portada del taller',
        shop.coverPath != null,
      ),
      ProfileTask(
        ProfileTaskKind.story,
        'Cuenta tu historia (mínimo 80 letras)',
        shop.bio.trim().length >= 80,
      ),
      ProfileTask(
        ProfileTaskKind.contact,
        'Agrega teléfono o WhatsApp',
        (shop.phone ?? '').isNotEmpty || (shop.whatsapp ?? '').isNotEmpty,
      ),
      ProfileTask(
        ProfileTaskKind.schedule,
        'Define tus días y horario',
        shop.hasSchedule,
      ),
      ProfileTask(
        ProfileTaskKind.product,
        'Publica tu primera pieza con foto',
        products.any((product) => product.photos.isNotEmpty),
      ),
      ProfileTask(
        ProfileTaskKind.service,
        'Publica una experiencia para recibir reservas',
        services.any((service) => service.isActive),
      ),
    ];
  }

  /// Si el teléfono debe mostrar avisos en la barra de notificaciones.
  bool get deviceNotificationsEnabled => _deviceNotificationsEnabled;

  /// Servicios del taller autenticado (incluye los desactivados).
  List<Experience> get myServices =>
      servicesOf(_user?.artisanId ?? '', includeInactive: true);

  /// Productos del taller autenticado (incluye los desactivados).
  List<Product> get myProducts =>
      productsOf(_user?.artisanId ?? '', includeInactive: true);

  // ---------------------------------------------------------------------------
  // Catálogo
  // ---------------------------------------------------------------------------

  List<Product> get allProducts => List.unmodifiable(_products);

  /// Piezas visibles para el turista.
  List<Product> get activeProducts => [
    for (final product in _products)
      if (product.isActive) product,
  ];

  List<Product> productsOf(String artisanId, {bool includeInactive = false}) =>
      [
        for (final product in _products)
          if (product.artisanId == artisanId &&
              (includeInactive || product.isActive))
            product,
      ];

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Experience> get allServices => List.unmodifiable(_services);

  /// Experiencias que el turista puede reservar.
  List<Experience> get activeServices => [
    for (final service in _services)
      if (service.isActive) service,
  ];

  /// Experiencias que el turista puede reservar: activas y de talleres con su
  /// mensualidad al día.
  List<Experience> get bookableServices => [
    for (final service in activeServices)
      if (isArtisanInService(service.artisanId)) service,
  ];

  List<Experience> servicesOf(
    String artisanId, {
    bool includeInactive = false,
  }) => [
    for (final service in _services)
      if (service.artisanId == artisanId &&
          (includeInactive || service.isActive))
        service,
  ];

  Experience? serviceById(String id) {
    for (final service in _services) {
      if (service.id == id) return service;
    }
    return null;
  }

  /// Reservaciones que puede ver el usuario actual.
  ///
  /// Un artesano solo ve las de su taller; un turista solo las suyas.
  List<Booking> get visibleBookings {
    final current = _user;
    if (current == null) return const [];

    final filtered = switch (current.role) {
      UserRole.artisan => _bookings.where(
        (booking) => booking.artisanId == current.artisanId,
      ),
      UserRole.tourist => _bookings.where(
        (booking) => booking.touristId == current.id,
      ),
      UserRole.admin => _bookings,
    };

    return filtered.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Solicitudes pendientes, de la más próxima a la más lejana.
  List<Booking> get pendingBookings => [
    for (final booking in visibleBookings)
      if (booking.status == BookingStatus.requested) booking,
  ]..sort((a, b) => a.date.compareTo(b.date));

  /// Visitas confirmadas próximas.
  List<Booking> get upcomingBookings => [
    for (final booking in visibleBookings)
      if (booking.status == BookingStatus.accepted) booking,
  ]..sort((a, b) => a.date.compareTo(b.date));

  MoneySummary get money => summariseMoney(visibleBookings);

  BookingCounters get counters => countBookings(visibleBookings);

  List<WeekBar> get weeklyCollected => collectedByWeek(visibleBookings);

  /// Experiencias más solicitadas (sin contar reservaciones de ejemplo).
  List<ServiceRank> get topServicesByVisits =>
      topServices(visibleBookings.where((booking) => !_isSeedBooking(booking)));

  Booking? bookingById(String id) {
    for (final booking in visibleBookings) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  /// Pedidos de compra que puede ver el usuario actual.
  ///
  /// El turista ve sus compras; el taller, las de sus piezas.
  List<Order> get visibleOrders {
    final current = _user;
    if (current == null) return const [];
    final list = switch (current.role) {
      UserRole.artisan => _orders.where(
        (order) => order.artisanId == current.artisanId,
      ),
      UserRole.tourist => _orders.where((order) => order.buyerId == current.id),
      UserRole.admin => _orders,
    }.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Pedidos que el taller todavía no confirma.
  int get pendingOrdersCount => visibleOrders
      .where((order) => order.status == OrderStatus.requested)
      .length;

  Order? orderById(String id) {
    for (final order in visibleOrders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Notificaciones del usuario actual, la más reciente primero.
  List<AppNotification> get myNotifications {
    final current = _user;
    if (current == null) return const [];
    final list = _notifications
        .where((notification) => notification.userId == current.id)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get unreadNotifications =>
      myNotifications.where((notification) => !notification.isRead).length;

  // ---------------------------------------------------------------------------
  // Sesión (API real)
  // ---------------------------------------------------------------------------

  ArtisanApplication? get application => _application;

  bool get hasPendingApplication =>
      _application != null && _application!.isPending;

  bool get isAdmin => _user?.role == UserRole.admin;

  /// Inicia sesión contra la API. Devuelve `null` si todo salió bien.
  Future<String?> signIn(String email, String password) async {
    try {
      final session = await _authApi.login(email: email, password: password);
      await _applySession(session);
      await _loadApplication();
      await _afterSignIn();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'No se pudo iniciar sesión. Intenta de nuevo.';
    }
  }

  /// Registro público: el backend **siempre** crea turistas.
  Future<String?> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    try {
      final session = await _authApi.register(
        nombre: nombre,
        email: email,
        password: password,
        telefono: telefono,
      );
      await _applySession(session);
      await _afterSignIn();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'No se pudo crear la cuenta. Intenta de nuevo.';
    }
  }

  /// Actualiza nombre y teléfono de la cuenta.
  Future<String?> updateMyAccount({String? name, String? phone}) async {
    final token = _accessToken;
    if (token == null) return 'Inicia sesión para continuar.';
    try {
      final updated = await _authApi.updateAccount(
        token,
        nombre: name,
        telefono: phone,
      );
      _user = updated;
      await _store.write(_userKey, jsonEncode(updated.toJson()));
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> changePassword(String current, String next) async {
    final token = _accessToken;
    if (token == null) return 'Inicia sesión para continuar.';
    try {
      await _authApi.changePassword(token, current: current, next: next);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Cambia la foto de perfil de la cuenta (o la del taller si es artesano).
  Future<void> setMyAvatar(String? path) async {
    await _pull();
    final current = _user;
    if (current == null) return;
    final shop = artisan;
    if (current.role == UserRole.artisan && shop != null) {
      final previous = shop.imagePath;
      await updateArtisanProfile(
        path == null
            ? shop.copyWith(clearImage: true)
            : shop.copyWith(imagePath: path),
      );
      if (previous != null && previous != path) {
        await PhotoService.delete(previous);
      }
      return;
    }
    final previous = _avatars[current.id];
    if (path == null) {
      _avatars.remove(current.id);
    } else {
      _avatars[current.id] = path;
    }
    await _store.write(_avatarsKey, jsonEncode(_avatars));
    if (previous != null && previous != path) {
      await PhotoService.delete(previous);
    }
    notifyListeners();
  }

  /// Guarda la ficha del taller del artesano autenticado.
  Future<String?> updateArtisanProfile(Artisan updated) async {
    await _pull();
    final current = _user;
    if (current == null ||
        current.role != UserRole.artisan ||
        current.artisanId != updated.id) {
      return 'Solo el taller puede editar su perfil.';
    }
    if (updated.name.trim().length < 3) {
      return 'Escribe el nombre del taller.';
    }
    final index = _artisans.indexWhere((item) => item.id == updated.id);
    if (index < 0) {
      _artisans.add(updated);
    } else {
      _artisans[index] = updated;
    }
    await _persistArtisans();
    notifyListeners();
    return null;
  }

  /// Activa o apaga los avisos en la barra de notificaciones.
  ///
  /// Al activarlos se pide permiso al sistema. Devuelve si quedaron activos.
  Future<bool> setDeviceNotificationsEnabled(bool enabled) async {
    var result = enabled;
    if (enabled) {
      result = await _device.requestPermission();
    }
    _deviceNotificationsEnabled = result;
    await _store.write(_deviceEnabledKey, result ? '1' : '0');
    if (result) {
      await _syncReminders();
    } else {
      await _device.cancelAll();
    }
    notifyListeners();
    return result;
  }

  /// Envía una notificación de prueba al teléfono.
  Future<void> sendTestNotification() => _device.show(
    id: 1,
    title: 'Bel-Aaktun',
    body: 'Así te avisaremos de nuevas reservas y recordatorios.',
  );

  /// Envía una solicitud de verificación de taller.
  Future<String?> submitArtisanApplication({
    required String nombreTaller,
    required String descripcion,
    String? ubicacion,
    String? direccion,
    String? telefono,
    String? oficio,
  }) async {
    final token = _accessToken;
    if (token == null) return 'Inicia sesión para continuar.';
    try {
      _application = await _authApi.submitApplication(
        token,
        nombreTaller: nombreTaller,
        descripcion: descripcion,
        ubicacion: ubicacion,
        direccion: direccion,
        telefono: telefono,
        oficio: oficio,
      );
      // Si la solicitud se aprobó al instante (modo local), el rol cambió.
      if (_application?.isApproved ?? false) {
        await refreshProfile();
      }
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> refreshApplication() => _loadApplication();

  /// Revalida la sesión contra la API (rol, estado y solicitud).
  Future<void> refreshProfile() async {
    await _pull();
    final token = _accessToken;
    if (token == null) return;
    try {
      final me = await _authApi.me(token);
      _user = me.user;
      _application = me.application;
      await _store.write(_userKey, jsonEncode(me.user.toJson()));
      await _ensureArtisanProfile();
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.isForbidden) {
        await _clearSession();
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    final access = _accessToken;
    final refresh = _refreshToken;
    if (access != null && refresh != null) {
      try {
        await _authApi.logout(accessToken: access, refreshToken: refresh);
      } catch (_) {
        // Aunque falle la red, la sesión local se cierra.
      }
    }
    await _device.cancelAll();
    await _clearSession();
    _cart = [];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Administración
  // ---------------------------------------------------------------------------

  Future<List<ArtisanApplication>> adminApplications({String? estado}) =>
      _withAuth((token) => _authApi.listApplications(token, estado: estado));

  Future<void> reviewApplication(
    int applicationId, {
    required String decision,
    String? motivo,
    String? notas,
  }) async {
    await _withAuth(
      (token) => _authApi.reviewApplication(
        token,
        applicationId,
        decision: decision,
        motivo: motivo,
        notas: notas,
      ),
    );
    await _loadApplication();
    notifyListeners();
  }

  Future<List<UserAccount>> adminUsers({String? rol}) =>
      _withAuth((token) => _authApi.listUsers(token, rol: rol));

  Future<void> suspendUser(int userId, String motivo) =>
      _withAuth((token) => _authApi.suspendUser(token, userId, motivo));

  Future<void> reactivateUser(int userId) =>
      _withAuth((token) => _authApi.reactivateUser(token, userId));

  Future<List<Map<String, dynamic>>> adminAudit() =>
      _withAuth((token) => _authApi.auditLog(token));

  Future<Map<String, int>> adminSummary() =>
      _withAuth((token) => _authApi.adminSummary(token));

  Future<T> _withAuth<T>(Future<T> Function(String token) action) async {
    final token = _accessToken;
    if (token == null) {
      throw ApiException(401, 'Inicia sesión para continuar.');
    }
    try {
      return await action(token);
    } on ApiException catch (error) {
      final refresh = _refreshToken;
      if (error.isUnauthorized && refresh != null) {
        try {
          final session = await _authApi.refresh(refresh);
          await _applySession(session);
          return await action(session.accessToken);
        } on ApiException catch (refreshError) {
          await _clearSession();
          notifyListeners();
          throw ApiException(401, refreshError.message);
        }
      }
      rethrow;
    }
  }

  Future<void> _applySession(AuthSession session) async {
    _user = session.user;
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
    await _store.write(_accessKey, session.accessToken);
    await _store.write(_refreshKey, session.refreshToken);
    await _store.write(_userKey, jsonEncode(session.user.toJson()));
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _application = null;
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
    await _store.delete(_userKey);
  }

  Future<void> _loadApplication() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      _application = await _authApi.myApplication(token);
      notifyListeners();
    } on ApiException {
      // Si falla, la app sigue funcionando sin bloquear la navegación.
    }
  }

  // ---------------------------------------------------------------------------
  // Reservaciones
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Disponibilidad de visitas
  // ---------------------------------------------------------------------------

  /// Minutos de anticipación mínima para reservar el mismo día.
  static const _sameDayLeadMinutes = 60;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int? _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  /// `true` si el taller abre ese día (sin horario definido, se asume que sí).
  bool isWorkshopOpenOn(Experience service, DateTime date) {
    final shop = artisanById(service.artisanId);
    if (shop == null || !shop.hasSchedule) return true;
    return shop.openDays.contains(date.weekday);
  }

  /// Horarios que se pueden reservar ese día: dentro del horario del taller
  /// (la visita debe terminar antes de cerrar) y, si es hoy, con al menos una
  /// hora de anticipación.
  List<String> slotsFor(Experience service, DateTime date, {DateTime? now}) {
    if (!isWorkshopOpenOn(service, date)) return const [];
    final shop = artisanById(service.artisanId);
    final open = shop != null && shop.hasSchedule
        ? _minutesOf(shop.openTime!)
        : null;
    final close = shop != null && shop.hasSchedule
        ? _minutesOf(shop.closeTime!)
        : null;
    final current = now ?? DateTime.now();
    final today = _sameDay(date, current);
    final earliest = current.hour * 60 + current.minute + _sameDayLeadMinutes;
    return [
      for (final slot in AppConfig.bookingTimeSlots)
        if (_slotFits(
          _minutesOf(slot),
          duration: service.durationMinutes,
          open: open,
          close: close,
          earliest: today ? earliest : null,
        ))
          slot,
    ];
  }

  static bool _slotFits(
    int? start, {
    required int duration,
    int? open,
    int? close,
    int? earliest,
  }) {
    if (start == null) return false;
    if (open != null && start < open) return false;
    if (close != null && start + duration > close) return false;
    if (earliest != null && start < earliest) return false;
    return true;
  }

  /// Lugares libres en un horario: cupo de la experiencia menos las personas
  /// de solicitudes y visitas confirmadas en ese mismo horario.
  int spotsLeft(Experience service, DateTime date, String slot) {
    var taken = 0;
    for (final booking in _bookings) {
      if (booking.serviceId != service.id || !booking.status.isActive) {
        continue;
      }
      if (!_sameDay(booking.date, date) || booking.timeSlot != slot) continue;
      taken += booking.people;
    }
    final left = service.maxParticipants - taken;
    return left < 0 ? 0 : left;
  }

  /// `null` si se puede reservar; si no, el motivo para mostrar al turista.
  String? bookingAvailabilityError({
    required Experience service,
    required DateTime date,
    required String timeSlot,
    required int people,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final live = serviceById(service.id) ?? service;
    if (!live.isActive) return 'Esta experiencia ya no está disponible.';
    final blocked = artisanServiceBlock(live.artisanId, now: current);
    if (blocked != null) return blocked;
    if (people < 1) return 'Elige al menos una persona.';
    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) return 'Elige una fecha a partir de hoy.';
    if (day.difference(today).inDays > AppConfig.bookingHorizonDays) {
      return 'Solo se puede reservar con hasta '
          '${AppConfig.bookingHorizonDays} días de anticipación.';
    }
    if (!isWorkshopOpenOn(live, day)) return 'El taller no abre ese día.';
    if (!slotsFor(live, day, now: current).contains(timeSlot)) {
      return 'Ese horario ya no está disponible. Elige otro.';
    }
    final left = spotsLeft(live, day, timeSlot);
    if (people > left) {
      return left == 0
          ? 'Ese horario ya está lleno. Elige otro.'
          : (left == 1
                ? 'Solo queda 1 lugar en ese horario.'
                : 'Solo quedan $left lugares en ese horario.');
    }
    return null;
  }

  /// Crea una solicitud de reserva a nombre del turista autenticado.
  ///
  /// Lanza [BookingRuleError] si el día, el horario o el cupo ya no están
  /// disponibles.
  Future<Booking> requestBooking({
    required Experience service,
    required DateTime date,
    required String timeSlot,
    required int people,
    required String name,
    required String phone,
    String? notes,
    UserRole createdAs = UserRole.tourist,
  }) async {
    await _pull();
    final problem = bookingAvailabilityError(
      service: service,
      date: date,
      timeSlot: timeSlot,
      people: people,
    );
    if (problem != null) throw BookingRuleError(problem);
    final current = _user;
    if (current != null && current.role != UserRole.tourist) {
      throw BookingRuleError(
        'Entra con una cuenta de visitante para reservar visitas.',
      );
    }
    final now = DateTime.now();
    final total = service.totalFor(people);
    final deposit = service.depositFor(people);

    final booking = Booking(
      id: 'bk-${now.microsecondsSinceEpoch}',
      folio: _nextFolio(),
      serviceId: service.id,
      serviceTitle: service.title,
      artisanId: service.artisanId,
      touristId: current?.id ?? '',
      touristName: name,
      touristPhone: phone,
      date: DateTime(date.year, date.month, date.day),
      timeSlot: timeSlot,
      people: people,
      status: BookingStatus.requested,
      totalAmount: total,
      depositAmount: deposit,
      depositStatus: deposit > 0
          ? DepositStatus.simulatedPaid
          : DepositStatus.none,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      // Reservación real de un usuario (el anticipo sigue siendo simulado).
      isDemo: false,
      history: [
        BookingEvent(
          status: BookingStatus.requested,
          at: now,
          byRole: createdAs.name,
        ),
      ],
    );

    _bookings.insert(0, booking);
    _addNotification(
      userId: _artisanUserId(booking.artisanId),
      type: AppNotificationType.newBooking,
      title: 'Nueva solicitud de ${booking.touristName}',
      body:
          '${booking.serviceTitle} · ${booking.people} '
          '${booking.people == 1 ? 'persona' : 'personas'} · '
          '${booking.timeSlot}',
      bookingId: booking.id,
    );
    _addNotification(
      userId: current?.id,
      type: AppNotificationType.requestSent,
      title: 'Solicitud enviada',
      body:
          '${booking.serviceTitle} · ${_shortDate(booking.date)} a las '
          '${booking.timeSlot}. Te avisaremos cuando el taller responda.',
      bookingId: booking.id,
    );

    await _persistBookings();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    return booking;
  }

  /// Cambia el estado de una reservación respetando las reglas del rol.
  ///
  /// Devuelve `null` si todo salió bien o el mensaje de error si no.
  Future<String?> changeBookingStatus(
    String bookingId,
    BookingStatus next, {
    String? note,
  }) async {
    await _pull();
    final current = _user;
    if (current == null) return 'Inicia sesión para continuar.';

    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index < 0) return 'No se encontró la reservación.';
    final target = _bookings[index];
    final mine = switch (current.role) {
      UserRole.artisan => target.artisanId == current.artisanId,
      UserRole.tourist => target.touristId == current.id,
      UserRole.admin => false,
    };
    if (!mine) return 'Esta reservación no es tuya.';

    try {
      final updated = BookingRules.apply(
        _bookings[index],
        next,
        by: current.role,
        note: note,
      );
      _bookings[index] = updated;
      _recordVisit(updated);
      await _notifyStatusChange(updated);
      await _persistBookings();
      await _persistLedger();
      notifyListeners();
      await _deliverPending();
      await _syncReminders();
      return null;
    } on BookingRuleError catch (error) {
      return error.message;
    }
  }

  // ---------------------------------------------------------------------------
  // Carrito y compras de piezas (recogida presencial en el taller)
  // ---------------------------------------------------------------------------

  /// Líneas del carrito con su pieza; omite piezas que ya no existen.
  List<({Product product, int quantity})> get cartItems => [
    for (final line in _cart)
      if (productById(line.productId) != null)
        (product: productById(line.productId)!, quantity: line.quantity),
  ];

  /// Número total de piezas en el carrito.
  int get cartCount => _cart.fold(0, (sum, line) => sum + line.quantity);

  /// Total del carrito en MXN (solo piezas con precio).
  int get cartTotal => cartItems.fold(
    0,
    (sum, item) => sum + (item.product.price ?? 0) * item.quantity,
  );

  int cartQuantityOf(String productId) {
    for (final line in _cart) {
      if (line.productId == productId) return line.quantity;
    }
    return 0;
  }

  /// Máximo de piezas que se pueden pedir (existencias o 20 por encargo).
  int maxQuantityOf(Product product) {
    if (!product.madeToOrder && product.stock != null) return product.stock!;
    return 20;
  }

  /// Agrega piezas al carrito. Devuelve `null` si todo bien o el error.
  Future<String?> addToCart(Product product, {int quantity = 1}) async {
    final current = _user;
    if (current == null) return 'Inicia sesión para comprar.';
    if (current.role != UserRole.tourist) {
      return 'Entra con una cuenta de visitante para comprar piezas.';
    }
    final live = productById(product.id) ?? product;
    if (!live.isActive) return 'Esta pieza ya no está disponible.';
    final blocked = artisanServiceBlock(live.artisanId);
    if (blocked != null) return blocked;
    if (live.price == null) {
      return 'Esta pieza es de precio a consultar: escribe al taller.';
    }
    if (live.isSoldOut) return 'Esta pieza está agotada por ahora.';
    final next = cartQuantityOf(live.id) + quantity;
    final max = maxQuantityOf(live);
    if (next > max) {
      return max <= 0
          ? 'Esta pieza está agotada por ahora.'
          : 'Solo hay $max disponibles.';
    }
    return _setCartLine(live.id, next);
  }

  /// Cambia la cantidad de una pieza del carrito (0 la quita).
  Future<String?> setCartQuantity(String productId, int quantity) async {
    final product = productById(productId);
    if (product != null && quantity > maxQuantityOf(product)) {
      return 'Solo hay ${maxQuantityOf(product)} disponibles.';
    }
    return _setCartLine(productId, quantity);
  }

  Future<void> removeFromCart(String productId) async {
    await _setCartLine(productId, 0);
  }

  Future<void> clearCart() async {
    _cart = [];
    await _persistCart();
    notifyListeners();
  }

  Future<String?> _setCartLine(String productId, int quantity) async {
    final index = _cart.indexWhere((line) => line.productId == productId);
    if (quantity <= 0) {
      if (index >= 0) _cart.removeAt(index);
    } else if (index >= 0) {
      _cart[index] = CartLine(productId: productId, quantity: quantity);
    } else {
      _cart.add(CartLine(productId: productId, quantity: quantity));
    }
    await _persistCart();
    notifyListeners();
    return null;
  }

  String? get _cartKey {
    final current = _user;
    return current == null ? null : 'cart.v1.${current.id}';
  }

  Future<void> _persistCart() async {
    final key = _cartKey;
    if (key == null) return;
    await _store.write(
      key,
      jsonEncode(_cart.map((line) => line.toJson()).toList()),
    );
  }

  void _loadCart() {
    final key = _cartKey;
    final raw = key == null ? null : _store.read(key);
    if (raw == null || raw.isEmpty) {
      _cart = [];
      return;
    }
    try {
      _cart = (jsonDecode(raw) as List<dynamic>)
          .map((item) => CartLine.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cart = [];
    }
  }

  /// Confirma el carrito: genera un pedido por taller, con recogida en el
  /// taller y pago al recoger. Devuelve los pedidos o el mensaje de error.
  Future<({List<Order> orders, String? error})> checkout({
    required String name,
    required String phone,
    String? notes,
  }) async {
    await _pull();
    final current = _user;
    if (current == null) {
      return (orders: const <Order>[], error: 'Inicia sesión para comprar.');
    }
    if (current.role != UserRole.tourist) {
      return (
        orders: const <Order>[],
        error: 'Entra con una cuenta de visitante para comprar piezas.',
      );
    }
    if (_cart.isEmpty) {
      return (orders: const <Order>[], error: 'Tu carrito está vacío.');
    }
    if (name.trim().length < 3) {
      return (orders: const <Order>[], error: 'Escribe tu nombre completo.');
    }
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      return (
        orders: const <Order>[],
        error: 'Escribe un teléfono de 10 dígitos.',
      );
    }

    // Revisa cada pieza con los datos más recientes del taller.
    final byArtisan = <String, List<OrderItem>>{};
    for (final line in _cart) {
      final product = productById(line.productId);
      final blocked = product == null
          ? null
          : artisanServiceBlock(product.artisanId);
      if (blocked != null) {
        return (orders: const <Order>[], error: blocked);
      }
      if (product == null || !product.isActive) {
        return (
          orders: const <Order>[],
          error:
              'Una pieza de tu carrito ya no está disponible. Quítala para '
              'continuar.',
        );
      }
      if (product.price == null) {
        return (
          orders: const <Order>[],
          error: '"${product.name}" es de precio a consultar; quítala.',
        );
      }
      if (line.quantity > maxQuantityOf(product)) {
        return (
          orders: const <Order>[],
          error:
              'De "${product.name}" solo hay ${maxQuantityOf(product)} '
              'disponibles.',
        );
      }
      byArtisan
          .putIfAbsent(product.artisanId, () => [])
          .add(
            OrderItem(
              productId: product.id,
              productName: product.name,
              productImage: product.coverImage,
              unitPrice: product.price!,
              quantity: line.quantity,
            ),
          );
    }

    final now = DateTime.now();
    final cleanNotes = (notes ?? '').trim().isEmpty ? null : notes!.trim();
    final created = <Order>[];
    var sequence = 0;
    for (final entry in byArtisan.entries) {
      final order = Order(
        id: 'od-${now.microsecondsSinceEpoch}-${sequence++}',
        folio: _nextOrderFolio(),
        artisanId: entry.key,
        buyerId: current.id,
        buyerName: name.trim(),
        buyerPhone: phone.trim(),
        items: entry.value,
        notes: cleanNotes,
        status: OrderStatus.requested,
        createdAt: now,
        updatedAt: now,
        history: [
          OrderEvent(
            status: OrderStatus.requested,
            at: now,
            byRole: current.role.name,
          ),
        ],
      );
      _orders.insert(0, order);
      created.add(order);
      _addNotification(
        userId: _artisanUserId(order.artisanId),
        type: AppNotificationType.newOrder,
        title: 'Nuevo pedido de ${order.buyerName}',
        body:
            '${order.title} · ${order.pieceCount} '
            '${order.pieceCount == 1 ? 'pieza' : 'piezas'} · '
            '${_money(order.total)}. Acéptalo y define la recogida.',
        bookingId: order.id,
      );
    }
    _addNotification(
      userId: current.id,
      type: AppNotificationType.orderUpdate,
      title: created.length == 1
          ? 'Pedido ${created.first.folio} enviado'
          : '${created.length} pedidos enviados',
      body: created.length == 1
          ? 'El taller lo revisará y te avisaremos cuándo recogerlo.'
          : 'Uno por cada taller. Te avisaremos cuándo recoger cada uno.',
      bookingId: created.first.id,
    );

    _cart = [];
    await _persistCart();
    await _persistOrders();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    return (orders: created, error: null);
  }

  /// Cambia el estado de un pedido. Al aceptarlo se apartan las existencias
  /// y, si se cancela después, se devuelven al inventario.
  Future<String?> changeOrderStatus(
    String orderId,
    OrderStatus next, {
    String? note,
    DateTime? pickupAt,
    String? pickupNote,
  }) async {
    await _pull();
    final current = _user;
    if (current == null) return 'Inicia sesión para continuar.';
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return 'No se encontró el pedido.';
    final order = _orders[index];
    if (!_isMyOrder(order, current)) return 'Este pedido no es tuyo.';

    Order updated;
    try {
      updated = OrderRules.apply(
        order,
        next,
        by: current.role,
        note: note,
        pickupAt: pickupAt,
      );
      final cleanPickupNote = (pickupNote ?? '').trim();
      if (cleanPickupNote.isNotEmpty) {
        updated = updated.copyWith(pickupNote: cleanPickupNote);
      }
    } on OrderRuleError catch (error) {
      return error.message;
    }

    // Apartar existencias al aceptar (todas o ninguna).
    if (next == OrderStatus.accepted && !order.stockReserved) {
      for (final item in order.items) {
        final product = productById(item.productId);
        final tracks =
            product != null && !product.madeToOrder && product.stock != null;
        if (tracks && product.stock! < item.quantity) {
          return product.stock! <= 0
              ? '"${item.productName}" está agotada. Actualiza tus '
                    'existencias o rechaza el pedido.'
              : 'De "${item.productName}" solo tienes ${product.stock}.';
        }
      }
      _adjustStock(order, -1);
      updated = updated.copyWith(stockReserved: true);
      await _persistCatalog();
    }
    final cancelled =
        next == OrderStatus.cancelledByArtisan ||
        next == OrderStatus.cancelledByBuyer;
    if (cancelled && order.stockReserved) {
      _adjustStock(order, 1);
      updated = updated.copyWith(stockReserved: false);
      await _persistCatalog();
    }

    _orders[index] = updated;
    _recordSale(updated);
    _notifyOrderChange(
      updated,
      byArtisan: current.role == UserRole.artisan,
      note: note,
    );
    await _persistOrders();
    await _persistLedger();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    await _syncReminders();
    return null;
  }

  /// El taller fija o cambia cuándo puede pasar el cliente por su pedido.
  Future<String?> scheduleOrderPickup(
    String orderId,
    DateTime pickupAt, {
    String? note,
  }) async {
    await _pull();
    final current = _user;
    if (current == null) return 'Inicia sesión para continuar.';
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return 'No se encontró el pedido.';
    if (!_isMyOrder(_orders[index], current)) return 'Este pedido no es tuyo.';
    try {
      final cleanNote = (note ?? '').trim().isEmpty ? null : note!.trim();
      final updated = OrderRules.schedulePickup(
        _orders[index],
        pickupAt,
        by: current.role,
        note: cleanNote,
      );
      _orders[index] = updated;
      final artisanName = artisanById(updated.artisanId)?.name ?? 'el taller';
      _addNotification(
        userId: updated.buyerId,
        type: AppNotificationType.orderUpdate,
        title: 'Fecha para recoger tu pedido',
        body:
            '${updated.title}: pasa a $artisanName el '
            '${_dateTime(pickupAt)}.${cleanNote == null ? '' : ' $cleanNote'}',
        bookingId: updated.id,
      );
    } on OrderRuleError catch (error) {
      return error.message;
    }
    await _persistOrders();
    await _persistNotifications();
    notifyListeners();
    await _deliverPending();
    await _syncReminders();
    return null;
  }

  bool _isMyOrder(Order order, User current) => switch (current.role) {
    UserRole.artisan => order.artisanId == current.artisanId,
    UserRole.tourist => order.buyerId == current.id,
    UserRole.admin => false,
  };

  /// Suma (`sign` = 1) o descuenta (`sign` = -1) las piezas del pedido.
  void _adjustStock(Order order, int sign) {
    for (final item in order.items) {
      final index = _products.indexWhere((p) => p.id == item.productId);
      if (index < 0) continue;
      final product = _products[index];
      if (product.madeToOrder || product.stock == null) continue;
      final next = product.stock! + sign * item.quantity;
      _products[index] = product.copyWith(stock: next < 0 ? 0 : next);
    }
  }

  void _notifyOrderChange(
    Order order, {
    required bool byArtisan,
    String? note,
  }) {
    final recipient = byArtisan
        ? order.buyerId
        : _artisanUserId(order.artisanId);
    final artisanName = artisanById(order.artisanId)?.name ?? 'el taller';
    final pickup = order.pickupAt == null
        ? null
        : 'el ${_dateTime(order.pickupAt!)}';
    final reason = note == null || note.isEmpty ? '' : ' Motivo: $note.';
    final (title, body) = switch (order.status) {
      OrderStatus.accepted => (
        'Tu pedido fue aceptado',
        pickup == null
            ? '${order.title}. $artisanName te avisará cuándo recogerlo.'
            : '${order.title}. Recógelo en $artisanName $pickup.'
                  '${order.pickupNote == null ? '' : ' ${order.pickupNote}'}',
      ),
      OrderStatus.preparing => (
        'Tu pedido está en preparación',
        '${order.title} · $artisanName.',
      ),
      OrderStatus.ready => (
        'Tu pedido está listo para recoger',
        'Pasa a $artisanName ${pickup ?? 'cuando gustes'}. '
            'Pagas ${_money(order.total)} al recoger.',
      ),
      OrderStatus.delivered => (
        'Pedido entregado',
        '${order.title}. ¡Gracias por comprar en Bécal!',
      ),
      OrderStatus.rejected => (
        'Pedido rechazado',
        '$artisanName no puede atender ${order.title}.$reason',
      ),
      OrderStatus.cancelledByArtisan => (
        'El taller canceló tu pedido',
        '${order.title}.$reason',
      ),
      OrderStatus.cancelledByBuyer => (
        '${order.buyerName} canceló su pedido',
        '${order.folio} · ${order.title}.$reason',
      ),
      OrderStatus.requested => ('Pedido recibido', order.title),
    };
    _addNotification(
      userId: recipient,
      type: AppNotificationType.orderUpdate,
      title: title,
      body: body,
      bookingId: order.id,
    );
  }

  String _money(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '\$$text';
  }

  String _dateTime(DateTime at) =>
      '${_shortDate(at)} a las '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Comisiones y registro financiero
  // ---------------------------------------------------------------------------

  /// Tasas de comisión vigentes.
  CommissionSettings get commissionSettings => _commission;

  /// Asientos que puede ver la cuenta actual: todos (admin) o los de su
  /// taller (artesano). El turista no ve finanzas.
  List<LedgerEntry> get ledgerEntries {
    final current = _user;
    if (current == null) return const [];
    final list = switch (current.role) {
      UserRole.admin => [..._ledger],
      UserRole.artisan => [
        for (final entry in _ledger)
          if (entry.artisanId == current.artisanId) entry,
      ],
      UserRole.tourist => <LedgerEntry>[],
    };
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Totales de los asientos visibles, filtrables por tipo y periodo.
  FinanceSummary financeSummary({LedgerSource? source, DateTime? since}) =>
      FinanceSummary.of(
        ledgerEntries.where(
          (entry) =>
              (source == null || entry.source == source) &&
              (since == null ||
                  !(entry.earnedAt ?? entry.createdAt).isBefore(since)),
        ),
      );

  /// Ingreso neto por semana de la cuenta actual (últimas 4 semanas).
  List<FinanceWeek> get netIncomeByWeek => netByWeek(ledgerEntries);

  /// Piezas más vendidas (pedidos entregados) del taller actual.
  List<({String name, int pieces, int gross})> get topProductsSold {
    final pieces = <String, int>{};
    final gross = <String, int>{};
    for (final order in visibleOrders) {
      if (order.status != OrderStatus.delivered) continue;
      for (final item in order.items) {
        pieces.update(
          item.productName,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
        gross.update(
          item.productName,
          (value) => value + item.subtotal,
          ifAbsent: () => item.subtotal,
        );
      }
    }
    final list = [
      for (final name in pieces.keys)
        (name: name, pieces: pieces[name]!, gross: gross[name]!),
    ]..sort((a, b) => b.gross.compareTo(a.gross));
    return list.take(5).toList();
  }

  /// Piezas activas del taller con 2 o menos en existencia.
  List<Product> get lowStockProducts => [
    for (final product in myProducts)
      if (product.isActive &&
          !product.madeToOrder &&
          product.stock != null &&
          product.stock! <= 2)
        product,
  ];

  LedgerEntry? ledgerEntryFor(LedgerSource source, String sourceId) {
    final key = LedgerEntry.keyFor(source, sourceId);
    for (final entry in _ledger) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  /// Desglose de un pedido: el registrado si ya fue aceptado o, si no, una
  /// estimación con la tasa vigente.
  CommissionSplit saleSplitFor(Order order) {
    final entry = ledgerEntryFor(LedgerSource.sale, order.id);
    if (entry != null) {
      return CommissionSplit(
        gross: entry.gross,
        rateBps: entry.rateBps,
        commission: entry.commission,
      );
    }
    return CommissionSplit.of(order.total, _commission.saleRateBps);
  }

  /// Cambia las tasas de comisión (solo administración). Solo afecta a las
  /// operaciones que se acepten después.
  Future<String?> setCommissionRates({
    int? saleRateBps,
    int? visitRateBps,
  }) async {
    await _pull();
    final current = _user;
    if (current == null || current.role != UserRole.admin) {
      return 'Solo la administración puede cambiar las comisiones.';
    }
    for (final rate in [saleRateBps, visitRateBps]) {
      if (rate != null && (rate < 0 || rate > CommissionSettings.maxRateBps)) {
        return 'La comisión debe estar entre 0 % y '
            '${formatRate(CommissionSettings.maxRateBps)}.';
      }
    }
    _commission = CommissionSettings(
      saleRateBps: saleRateBps ?? _commission.saleRateBps,
      visitRateBps: visitRateBps ?? _commission.visitRateBps,
      updatedAt: DateTime.now(),
      updatedBy: current.name,
    );
    await _store.write(_commissionKey, jsonEncode(_commission.toJson()));
    notifyListeners();
    return null;
  }

  /// Registra que el taller pagó a la plataforma la comisión de una
  /// operación completada. Requiere una referencia real del pago.
  Future<String?> registerSettlement(String entryId, String reference) async {
    await _pull();
    final current = _user;
    if (current == null || current.role != UserRole.admin) {
      return 'Solo la administración puede registrar liquidaciones.';
    }
    final ref = reference.trim();
    if (ref.length < 3) {
      return 'Escribe la referencia del pago (recibo, transferencia…).';
    }
    final index = _ledger.indexWhere((entry) => entry.id == entryId);
    if (index < 0) return 'No se encontró el movimiento.';
    final entry = _ledger[index];
    if (entry.status != LedgerStatus.earned) {
      return 'Solo se liquidan comisiones de operaciones completadas.';
    }
    if (entry.isSettled) return 'Esta comisión ya está liquidada.';
    final now = DateTime.now();
    _ledger[index] = entry.copyWith(
      settledAt: now,
      settlementRef: ref,
      updatedAt: now,
      history: [
        ...entry.history,
        LedgerEvent(
          status: entry.status,
          at: now,
          note: 'Liquidada por ${current.name} · Ref. $ref',
        ),
      ],
    );
    await _persistLedger();
    notifyListeners();
    return null;
  }

  /// Lleva el asiento de una operación al estado que le corresponde.
  ///
  /// Idempotente: un solo asiento por operación. [target] `null` significa
  /// "aceptada, en curso" (crea el asiento por confirmar si no existe).
  /// Una operación que se cierra sin haberse aceptado nunca crea asiento.
  void _upsertLedger({
    required LedgerSource source,
    required String sourceId,
    required String folio,
    required String artisanId,
    required String customerName,
    required String description,
    required int gross,
    required LedgerStatus? target,
    required String note,
  }) {
    final key = LedgerEntry.keyFor(source, sourceId);
    final index = _ledger.indexWhere((entry) => entry.key == key);
    final existing = index >= 0 ? _ledger[index] : null;
    final now = DateTime.now();

    LedgerEntry create(String createNote) {
      final split = CommissionSplit.of(gross, _commission.rateFor(source));
      return LedgerEntry(
        id: 'lg-${now.microsecondsSinceEpoch}-${_ledger.length}',
        source: source,
        sourceId: sourceId,
        folio: folio,
        artisanId: artisanId,
        customerName: customerName,
        description: description,
        gross: split.gross,
        rateBps: split.rateBps,
        commission: split.commission,
        status: LedgerStatus.pending,
        createdAt: now,
        updatedAt: now,
        history: [
          LedgerEvent(status: LedgerStatus.pending, at: now, note: createNote),
        ],
      );
    }

    LedgerEntry move(LedgerEntry entry, LedgerStatus status) {
      if (entry.status == status) return entry;
      return entry.copyWith(
        status: status,
        updatedAt: now,
        earnedAt: status == LedgerStatus.earned ? now : null,
        history: [
          ...entry.history,
          LedgerEvent(status: status, at: now, note: note),
        ],
      );
    }

    LedgerEntry? next;
    switch (target) {
      case null:
      case LedgerStatus.pending:
        next = existing ?? create(note);
      case LedgerStatus.earned:
        next = move(existing ?? create('Aceptada'), LedgerStatus.earned);
      case LedgerStatus.voided:
        if (existing != null) next = move(existing, LedgerStatus.voided);
    }
    if (next == null || identical(next, existing)) return;
    if (index >= 0) {
      _ledger[index] = next;
    } else {
      _ledger.add(next);
    }
  }

  /// Asiento de una venta según el estado del pedido.
  void _recordSale(Order order) {
    final LedgerStatus? target;
    switch (order.status) {
      case OrderStatus.requested:
        return;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        target = null;
      case OrderStatus.delivered:
        target = LedgerStatus.earned;
      case OrderStatus.rejected:
      case OrderStatus.cancelledByArtisan:
      case OrderStatus.cancelledByBuyer:
        target = LedgerStatus.voided;
    }
    _upsertLedger(
      source: LedgerSource.sale,
      sourceId: order.id,
      folio: order.folio,
      artisanId: order.artisanId,
      customerName: order.buyerName,
      description: order.title,
      gross: order.total,
      target: target,
      note: order.status == OrderStatus.accepted
          ? 'Pedido aceptado'
          : order.status.label,
    );
  }

  /// Las reservaciones de ejemplo no son operaciones reales.
  bool _isSeedBooking(Booking booking) => booking.id.startsWith('bk-seed-');

  /// Asiento de una visita según el estado de la reservación.
  ///
  /// La comisión se calcula sobre el precio total de la experiencia y solo
  /// se devenga cuando la visita se realiza. Cancelaciones y no-shows la
  /// anulan: el anticipo todavía es simulado y no hubo servicio.
  void _recordVisit(Booking booking) {
    if (_isSeedBooking(booking) || booking.artisanId.isEmpty) return;
    final LedgerStatus? target;
    switch (booking.status) {
      case BookingStatus.requested:
        return;
      case BookingStatus.accepted:
        target = null;
      case BookingStatus.completed:
        target = LedgerStatus.earned;
      case BookingStatus.rejected:
      case BookingStatus.cancelledByTourist:
      case BookingStatus.cancelledByArtisan:
      case BookingStatus.noShow:
        target = LedgerStatus.voided;
    }
    final people = booking.people == 1 ? 'persona' : 'personas';
    _upsertLedger(
      source: LedgerSource.visit,
      sourceId: booking.id,
      folio: booking.folio,
      artisanId: booking.artisanId,
      customerName: booking.touristName,
      description: '${booking.serviceTitle} · ${booking.people} $people',
      gross: booking.totalAmount,
      target: target,
      note: booking.status == BookingStatus.accepted
          ? 'Visita confirmada'
          : booking.status.label,
    );
  }

  /// Desglose de una reservación: el registrado si ya fue confirmada o, si
  /// no, una estimación con la tasa vigente.
  CommissionSplit visitSplitFor(Booking booking) {
    final entry = ledgerEntryFor(LedgerSource.visit, booking.id);
    if (entry != null) {
      return CommissionSplit(
        gross: entry.gross,
        rateBps: entry.rateBps,
        commission: entry.commission,
      );
    }
    return CommissionSplit.of(booking.totalAmount, _commission.visitRateBps);
  }

  /// Crea los asientos que falten de operaciones aceptadas antes de que
  /// existiera el registro financiero. Devuelve `true` si agregó alguno.
  bool _reconcileSales() {
    var changed = false;
    for (final order in _orders) {
      final relevant =
          order.status.isAcceptedByArtisan ||
          order.status == OrderStatus.delivered;
      if (!relevant) continue;
      if (ledgerEntryFor(LedgerSource.sale, order.id) != null) continue;
      _recordSale(order);
      changed = true;
    }
    for (final booking in _bookings) {
      final relevant =
          booking.status == BookingStatus.accepted ||
          booking.status == BookingStatus.completed;
      if (!relevant || _isSeedBooking(booking)) continue;
      if (ledgerEntryFor(LedgerSource.visit, booking.id) != null) continue;
      _recordVisit(booking);
      changed = true;
    }
    return changed;
  }

  /// Solo talleres y administración completan asientos faltantes.
  Future<void> _reconcileLedgerIfStaff() async {
    final role = _user?.role;
    if (role == null || role == UserRole.tourist) return;
    if (_reconcileSales()) await _persistLedger();
  }

  Future<void> _persistLedger() => _store.write(
    _ledgerKey,
    jsonEncode(_ledger.map((entry) => entry.toJson()).toList()),
  );

  List<LedgerEntry> _decodeLedger() {
    final raw = _store.read(_ledgerKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  CommissionSettings _decodeCommission() {
    final raw = _store.read(_commissionKey);
    if (raw == null || raw.isEmpty) return const CommissionSettings();
    try {
      return CommissionSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const CommissionSettings();
    }
  }

  Future<void> _persistOrders() => _store.write(
    _ordersKey,
    jsonEncode(_orders.map((order) => order.toJson()).toList()),
  );

  List<Order> _decodeOrders() {
    final raw = _store.read(_ordersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _nextOrderFolio() {
    var max = 1000;
    for (final order in _orders) {
      final value = int.tryParse(order.folio.replaceFirst('PD-', ''));
      if (value != null && value > max) max = value;
    }
    return 'PD-${max + 1}';
  }

  // ---------------------------------------------------------------------------
  // Notificaciones
  // ---------------------------------------------------------------------------

  Future<void> markNotificationRead(String id) async {
    await _pull();
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index < 0 || _notifications[index].isRead) return;
    if (_notifications[index].userId != _user?.id) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    await _persistNotifications();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await _pull();
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == _user?.id && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (!changed) return;
    await _persistNotifications();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Catálogo editable
  // ---------------------------------------------------------------------------

  bool get _canEditCatalog {
    final current = _user;
    return current != null &&
        current.role == UserRole.artisan &&
        current.artisanId != null;
  }

  /// Crea o actualiza una pieza del taller autenticado.
  ///
  /// Devuelve `null` si se guardó o el mensaje de error.
  Future<String?> upsertProduct({
    String? id,
    required String name,
    required String category,
    required String description,
    required String technique,
    required int? price,
    required bool madeToOrder,
    required bool isActive,
    List<String>? photos,
    int? stock,
    int? productionDays,
    String? dimensions,
    List<String> materials = const [],
  }) async {
    await _pull();
    if (!_canEditCatalog) {
      return 'Solo el taller puede editar su catálogo.';
    }
    final cleanName = name.trim();
    if (stock != null && stock < 0) {
      return 'Las existencias no pueden ser negativas.';
    }
    if (cleanName.length < 2) return 'Escribe un nombre para la pieza.';
    if (price != null && price < 0) {
      return 'El precio no puede ser negativo.';
    }

    final artisanId = _user!.artisanId!;
    final index = id == null
        ? -1
        : _products.indexWhere((product) => product.id == id);
    if (id != null && index < 0) return 'No se encontró esa pieza.';
    if (index >= 0 && _products[index].artisanId != artisanId) {
      return 'Esa pieza pertenece a otro taller.';
    }

    final product = Product(
      id: id ?? 'prod-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
      artisanId: artisanId,
      category: category,
      description: description.trim(),
      technique: technique.trim(),
      price: price,
      madeToOrder: madeToOrder,
      isActive: isActive,
      imagePath: index >= 0 ? _products[index].imagePath : null,
      photos: photos ?? (index >= 0 ? _products[index].photos : const []),
      stock: stock,
      productionDays: madeToOrder ? productionDays : null,
      dimensions: (dimensions ?? '').trim().isEmpty ? null : dimensions!.trim(),
      materials: materials,
    );

    if (index >= 0) {
      await _deleteRemovedPhotos(_products[index].photos, product.photos);
      _products[index] = product;
    } else {
      _products.insert(0, product);
    }
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  /// Ajusta las existencias de una pieza del taller (inventario).
  Future<String?> setProductStock(String id, int stock) async {
    await _pull();
    if (!_canEditCatalog) return 'Solo el taller puede editar su catálogo.';
    if (stock < 0) return 'Las existencias no pueden ser negativas.';
    final index = _products.indexWhere((product) => product.id == id);
    if (index < 0) return 'No se encontró esa pieza.';
    final product = _products[index];
    if (product.artisanId != _user!.artisanId) {
      return 'Esa pieza pertenece a otro taller.';
    }
    if (product.madeToOrder) {
      return 'Las piezas por encargo no llevan existencias.';
    }
    _products[index] = product.copyWith(stock: stock);
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  Future<String?> setProductActive(String id, bool active) async {
    await _pull();
    if (!_canEditCatalog) return 'Solo el taller puede editar su catálogo.';
    final index = _products.indexWhere((product) => product.id == id);
    if (index < 0) return 'No se encontró esa pieza.';
    if (_products[index].artisanId != _user!.artisanId) {
      return 'Esa pieza pertenece a otro taller.';
    }

    _products[index] = _products[index].copyWith(isActive: active);
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  Future<String?> deleteProduct(String id) async {
    await _pull();
    if (!_canEditCatalog) return 'Solo el taller puede editar su catálogo.';
    final index = _products.indexWhere((product) => product.id == id);
    if (index < 0) return 'No se encontró esa pieza.';
    if (_products[index].artisanId != _user!.artisanId) {
      return 'Esa pieza pertenece a otro taller.';
    }

    final removed = _products.removeAt(index);
    await _deleteRemovedPhotos(removed.photos, const []);
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Supervisión de la plataforma (solo administración)
  // ---------------------------------------------------------------------------

  /// Todas las reservaciones (la administración ve las de todos los talleres).
  List<Booking> get allBookingsForAdmin =>
      isAdmin ? visibleBookings : const <Booking>[];

  /// Indica si una reservación es de los datos de ejemplo.
  bool isSampleBooking(Booking booking) => _isSeedBooking(booking);

  /// Cifras generales de la plataforma para el panel de administración.
  PlatformStats get platformStats {
    final orders = isAdmin ? _orders : const <Order>[];
    final bookings = isAdmin
        ? _bookings.where((booking) => !_isSeedBooking(booking))
        : const <Booking>[];
    return PlatformStats(
      publishedArtisans: _artisans
          .where((artisan) => artisan.isPublished)
          .length,
      activeProducts: _products.where((product) => product.isActive).length,
      totalProducts: _products.length,
      activeServices: _services.where((service) => service.isActive).length,
      totalServices: _services.length,
      ordersOpen: orders.where((order) => order.status.isOpen).length,
      ordersPendingAcceptance: orders
          .where((order) => order.status == OrderStatus.requested)
          .length,
      ordersDelivered: orders
          .where((order) => order.status == OrderStatus.delivered)
          .length,
      ordersCancelled: orders
          .where(
            (order) =>
                order.status == OrderStatus.rejected ||
                order.status == OrderStatus.cancelledByArtisan ||
                order.status == OrderStatus.cancelledByBuyer,
          )
          .length,
      bookingsRequested: bookings
          .where((booking) => booking.status == BookingStatus.requested)
          .length,
      bookingsConfirmed: bookings
          .where((booking) => booking.status == BookingStatus.accepted)
          .length,
      bookingsCompleted: bookings
          .where((booking) => booking.status == BookingStatus.completed)
          .length,
    );
  }

  /// La administración oculta o vuelve a mostrar una pieza de cualquier
  /// taller (moderación). El taller recibe un aviso con el motivo.
  Future<String?> adminSetProductActive(
    String id,
    bool active, {
    String? reason,
  }) async {
    await _pull();
    if (!isAdmin) return 'Solo la administración puede moderar el catálogo.';
    final index = _products.indexWhere((product) => product.id == id);
    if (index < 0) return 'No se encontró esa pieza.';
    final product = _products[index];
    _products[index] = product.copyWith(isActive: active);
    _notifyModeration(
      artisanId: product.artisanId,
      what: 'tu pieza “${product.name}”',
      active: active,
      reason: reason,
    );
    await _persistCatalog();
    await _persistNotifications();
    notifyListeners();
    return null;
  }

  /// La administración oculta o vuelve a mostrar una experiencia.
  Future<String?> adminSetServiceActive(
    String id,
    bool active, {
    String? reason,
  }) async {
    await _pull();
    if (!isAdmin) return 'Solo la administración puede moderar el catálogo.';
    final index = _services.indexWhere((service) => service.id == id);
    if (index < 0) return 'No se encontró esa experiencia.';
    final service = _services[index];
    _services[index] = service.copyWith(isActive: active);
    _notifyModeration(
      artisanId: service.artisanId,
      what: 'tu experiencia “${service.title}”',
      active: active,
      reason: reason,
    );
    await _persistCatalog();
    await _persistNotifications();
    notifyListeners();
    return null;
  }

  void _notifyModeration({
    required String artisanId,
    required String what,
    required bool active,
    String? reason,
  }) {
    final clean = (reason ?? '').trim();
    _addNotification(
      userId: _artisanUserId(artisanId),
      type: AppNotificationType.orderUpdate,
      title: active
          ? 'Bel-Aaktun volvió a publicar $what'
          : 'Bel-Aaktun ocultó $what',
      body: active
          ? 'Ya es visible para los turistas.'
          : (clean.isEmpty
                ? 'Escribe a la administración si tienes dudas.'
                : 'Motivo: $clean'),
    );
  }

  /// Crea una copia de una pieza (útil para variantes de color o talla).
  Future<String?> duplicateProduct(String id) async {
    final original = productById(id);
    if (original == null) return 'No se encontró esa pieza.';
    return upsertProduct(
      name: '${original.name} (copia)',
      category: original.category,
      description: original.description,
      technique: original.technique,
      price: original.price,
      madeToOrder: original.madeToOrder,
      isActive: false,
      photos: const [],
      stock: original.stock,
      productionDays: original.productionDays,
      dimensions: original.dimensions,
      materials: original.materials,
    );
  }

  /// Crea o actualiza una experiencia del taller autenticado.
  Future<String?> upsertService({
    String? id,
    required String title,
    required String description,
    required int durationMinutes,
    required int pricePerPerson,
    required int depositPercent,
    required int maxParticipants,
    required bool isActive,
    List<String>? photos,
    List<String> includes = const [],
    String? whatToBring,
    List<String> languages = const [],
    String? meetingPoint,
  }) async {
    await _pull();
    if (!_canEditCatalog) {
      return 'Solo el taller puede editar su catálogo.';
    }
    if (title.trim().length < 3) {
      return 'Escribe un nombre para la experiencia.';
    }
    if (durationMinutes < 15) return 'La duración mínima es de 15 minutos.';
    if (pricePerPerson < 0) return 'El precio no puede ser negativo.';
    if (depositPercent < 0 || depositPercent > 100) {
      return 'El anticipo debe estar entre 0 y 100 %.';
    }
    if (maxParticipants < 1) return 'El cupo debe ser de al menos 1 persona.';

    final artisanId = _user!.artisanId!;
    final index = id == null
        ? -1
        : _services.indexWhere((service) => service.id == id);
    if (id != null && index < 0) return 'No se encontró esa experiencia.';
    if (index >= 0 && _services[index].artisanId != artisanId) {
      return 'Esa experiencia pertenece a otro taller.';
    }

    final service = Experience(
      id: id ?? 'exp-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim(),
      durationMinutes: durationMinutes,
      artisanId: artisanId,
      pricePerPerson: pricePerPerson,
      depositPercent: depositPercent,
      maxParticipants: maxParticipants,
      isActive: isActive,
      imagePath: index >= 0 ? _services[index].imagePath : null,
      photos: photos ?? (index >= 0 ? _services[index].photos : const []),
      includes: includes,
      whatToBring: (whatToBring ?? '').trim().isEmpty
          ? null
          : whatToBring!.trim(),
      languages: languages,
      meetingPoint: (meetingPoint ?? '').trim().isEmpty
          ? null
          : meetingPoint!.trim(),
    );

    if (index >= 0) {
      await _deleteRemovedPhotos(_services[index].photos, service.photos);
      _services[index] = service;
    } else {
      _services.insert(0, service);
    }
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  Future<String?> setServiceActive(String id, bool active) async {
    await _pull();
    if (!_canEditCatalog) return 'Solo el taller puede editar su catálogo.';
    final index = _services.indexWhere((service) => service.id == id);
    if (index < 0) return 'No se encontró esa experiencia.';
    if (_services[index].artisanId != _user!.artisanId) {
      return 'Esa experiencia pertenece a otro taller.';
    }

    _services[index] = _services[index].copyWith(isActive: active);
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  Future<String?> deleteService(String id) async {
    await _pull();
    if (!_canEditCatalog) return 'Solo el taller puede editar su catálogo.';
    final index = _services.indexWhere((service) => service.id == id);
    if (index < 0) return 'No se encontró esa experiencia.';
    if (_services[index].artisanId != _user!.artisanId) {
      return 'Esa experiencia pertenece a otro taller.';
    }

    final removed = _services.removeAt(index);
    await _deleteRemovedPhotos(removed.photos, const []);
    await _persistCatalog();
    notifyListeners();
    return null;
  }

  Future<void> _persistCatalog() => _catalogRepository.save(
    CatalogData(products: _products, services: _services),
  );

  Future<void> _deleteRemovedPhotos(
    List<String> before,
    List<String> after,
  ) async {
    for (final path in before) {
      if (!after.contains(path)) await PhotoService.delete(path);
    }
  }

  Future<void> _persistArtisans() => _store.write(
    _artisansKey,
    jsonEncode(_artisans.map((artisan) => artisan.toJson()).toList()),
  );

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  Future<void> _restore() async {
    final access = _store.read(_accessKey);
    final refresh = _store.read(_refreshKey);

    if (access != null && access.isNotEmpty) {
      _accessToken = access;
      _refreshToken = refresh;
      try {
        final me = await _authApi.me(access);
        _user = me.user;
        _application = me.application;
        await _store.write(_userKey, jsonEncode(me.user.toJson()));
      } on ApiException catch (error) {
        if (error.isUnauthorized && refresh != null && refresh.isNotEmpty) {
          try {
            final session = await _authApi.refresh(refresh);
            await _applySession(session);
            final me = await _authApi.me(session.accessToken);
            _user = me.user;
            _application = me.application;
          } on ApiException {
            await _clearSession();
          }
        } else if (error.isUnauthorized || error.isForbidden) {
          await _clearSession();
        } else {
          await _restoreCachedUser();
        }
      } catch (_) {
        // Sin red: se usa el último perfil guardado para no dejar la app vacía.
        await _restoreCachedUser();
      }
    }

    _bookings = await _repository.load();
    _notifications = _decodeNotifications();
    _artisans = _decodeArtisans();
    _avatars = _decodeAvatars();
    _orders = _decodeOrders();
    _ledger = _decodeLedger();
    _commission = _decodeCommission();
    _deviceNotificationsEnabled = _store.read(_deviceEnabledKey) != '0';

    final catalog = await _catalogRepository.load();
    _products = catalog.products;
    _services = catalog.services;

    await _removeSampleData();
    await _ensureShowcase();

    if (_bookings.isEmpty && AppConfig.seedSampleData) {
      _bookings = seedBookings();
      if (_notifications.isEmpty) _notifications = seedNotifications();
      await _persistBookings();
      await _persistNotifications();
    }

    await _ensureArtisanProfile();
    _loadCart();
    await _reconcileLedgerIfStaff();
    _ready = true;
    notifyListeners();
    await _deliverPending();
    await _syncReminders();
  }

  /// Pasos comunes tras iniciar sesión o crear la cuenta.
  Future<void> _afterSignIn() async {
    await _pull();
    _loadCart();
    await _ensureArtisanProfile();
    await _claimDemoData();
    await _reconcileLedgerIfStaff();
    notifyListeners();
    if (_store.read(_permissionAskedKey) == null) {
      await _store.write(_permissionAskedKey, '1');
      _deviceNotificationsEnabled = await _device.requestPermission();
      await _store.write(
        _deviceEnabledKey,
        _deviceNotificationsEnabled ? '1' : '0',
      );
    }
    await _deliverPending();
    await _syncReminders();
  }

  /// Crea o enlaza la ficha del taller de un artesano recién aprobado.
  Future<void> _ensureArtisanProfile() async {
    final current = _user;
    final artisanId = current?.artisanId;
    if (current == null ||
        current.role != UserRole.artisan ||
        artisanId == null) {
      return;
    }
    final index = _artisans.indexWhere((item) => item.id == artisanId);
    if (index >= 0) {
      if (_artisans[index].ownerUserId == null) {
        _artisans[index] = _artisans[index].copyWith(ownerUserId: current.id);
        await _persistArtisans();
        await _claimDemoData();
      }
      return;
    }
    final application = _application;
    final name = application?.nombreTaller ?? '';
    _artisans.add(
      Artisan(
        id: artisanId,
        name: name.isNotEmpty ? name : current.name,
        craft: application?.oficio ?? 'Artesanía de Bécal',
        cave: application?.ubicacion ?? 'Bécal, Campeche',
        bio: application?.descripcion ?? '',
        techniques: const [],
        yearsOfCraft: 0,
        ownerUserId: current.id,
        phone: application?.telefono ?? current.phone,
        whatsapp: application?.telefono ?? current.phone,
        email: current.email,
        address: application?.direccion,
      ),
    );
    await _persistArtisans();
  }

  /// En las cuentas de demostración, enlaza las reservas y avisos de ejemplo.
  Future<void> _claimDemoData() async {
    final current = _user;
    if (current == null) return;
    final aliases = <String>{
      if (current.artisanId != null) 'u-${current.artisanId}',
      if (current.email == 'turista@belaaktun.mx') 'u-turista',
    };
    if (aliases.isEmpty) return;
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      final item = _notifications[i];
      if (aliases.contains(item.userId)) {
        _notifications[i] = AppNotification(
          id: item.id,
          userId: current.id,
          type: item.type,
          title: item.title,
          body: item.body,
          bookingId: item.bookingId,
          isRead: item.isRead,
          createdAt: item.createdAt,
          delivered: item.delivered,
        );
        changed = true;
      }
    }
    for (var i = 0; i < _bookings.length; i++) {
      if (aliases.contains(_bookings[i].touristId)) {
        _bookings[i] = _bookings[i].copyWith(touristId: current.id);
        changed = true;
      }
    }
    if (changed) {
      await _persistNotifications();
      await _persistBookings();
    }
  }

  /// Muestra en la barra del teléfono los avisos nuevos del usuario actual.
  Future<void> _deliverPending() async {
    final current = _user;
    if (current == null) return;
    final pending = [
      for (final item in _notifications)
        if (item.userId == current.id && !item.delivered) item,
    ];
    if (pending.isEmpty) return;

    if (_deviceNotificationsEnabled) {
      pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final many = pending.length > 4;
      final toShow = many ? pending.sublist(pending.length - 3) : pending;
      if (many) {
        await _device.show(
          id: 2,
          title: 'Tienes ${pending.length} avisos nuevos',
          body: 'Abre Bel-Aaktun para revisarlos.',
        );
      }
      for (final item in toShow) {
        await _device.show(
          id: item.id.hashCode & 0x3FFFFFF,
          title: item.title,
          body: item.body,
          payload: item.bookingId,
        );
      }
    }
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == current.id &&
          !_notifications[i].delivered) {
        _notifications[i] = _notifications[i].copyWith(delivered: true);
      }
    }
    await _persistNotifications();
  }

  /// Programa recordatorios de las visitas confirmadas del usuario actual.
  Future<void> _syncReminders() async {
    final current = _user;
    if (current == null ||
        !_deviceNotificationsEnabled ||
        current.role == UserRole.admin) {
      await _device.replaceReminders(const []);
      return;
    }
    final isArtisan = current.role == UserRole.artisan;
    final reminders = <ScheduledReminder>[];
    for (final booking in visibleBookings) {
      if (booking.status != BookingStatus.accepted) continue;
      final visit = _visitDateTime(booking);
      if (visit == null) continue;
      final base =
          LocalDeviceNotifications.reminderIdBase +
          (booking.id.hashCode & 0xFFFFF) * 2;
      final people =
          '${booking.people} ${booking.people == 1 ? 'persona' : 'personas'}';
      reminders
        ..add(
          ScheduledReminder(
            id: base,
            at: visit.subtract(const Duration(hours: 24)),
            title: isArtisan
                ? 'Mañana recibes a ${booking.touristName}'
                : 'Mañana es tu visita',
            body: '${booking.serviceTitle} · ${booking.timeSlot} · $people.',
            payload: booking.id,
          ),
        )
        ..add(
          ScheduledReminder(
            id: base + 1,
            at: visit.subtract(const Duration(hours: 2)),
            title: isArtisan
                ? 'Visita en 2 horas'
                : 'Tu visita empieza en 2 horas',
            body: isArtisan
                ? '${booking.touristName} · ${booking.serviceTitle} · '
                      '${booking.timeSlot}.'
                : '${booking.serviceTitle} a las ${booking.timeSlot}. '
                      '¡Te esperamos en Bécal!',
            payload: booking.id,
          ),
        );
    }
    // Recogida de pedidos: aviso 2 horas antes de la hora acordada.
    for (final order in visibleOrders) {
      final at = order.pickupAt;
      if (at == null || !order.status.isAcceptedByArtisan) continue;
      reminders.add(
        ScheduledReminder(
          id:
              LocalDeviceNotifications.reminderIdBase +
              0x200000 +
              (order.id.hashCode & 0xFFFFF),
          at: at.subtract(const Duration(hours: 2)),
          title: isArtisan
              ? 'En 2 horas recogen el pedido ${order.folio}'
              : 'Hoy recoges tu pedido',
          body: isArtisan
              ? '${order.buyerName} · ${order.title}.'
              : '${order.title} a las ${at.hour.toString().padLeft(2, '0')}:'
                    '${at.minute.toString().padLeft(2, '0')}. Pagas al recoger.',
          payload: order.id,
        ),
      );
    }
    await _device.replaceReminders(reminders);
  }

  DateTime? _visitDateTime(Booking booking) {
    final parts = booking.timeSlot.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      hour,
      minute,
    );
  }

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String _shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';

  List<Artisan> _decodeArtisans() {
    final raw = _store.read(_artisansKey);
    if (raw == null || raw.isEmpty) return [...DemoContent.artisans];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => Artisan.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [...DemoContent.artisans];
    }
  }

  Map<String, String> _decodeAvatars() {
    final raw = _store.read(_avatarsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _restoreCachedUser() async {
    final cached = _store.read(_userKey);
    if (cached == null || cached.isEmpty) return;
    try {
      _user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      _user = null;
    }
  }

  List<AppNotification> _decodeNotifications() {
    final raw = _store.read(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistBookings() => _repository.save(_bookings);

  /// Agrega los dos talleres de muestra (activo y fuera de servicio) si no
  /// están. Solo en la versión del piloto, no con los datos de ejemplo.
  Future<void> _ensureShowcase() async {
    if (!AppConfig.showShowcaseArtisans || AppConfig.seedSampleData) return;
    var artisansChanged = false;
    for (final sample in DemoContent.showcaseArtisans) {
      if (!_artisans.any((item) => item.id == sample.id)) {
        _artisans.add(sample);
        artisansChanged = true;
      }
    }
    if (artisansChanged) await _persistArtisans();
    final products = [
      for (final sample in DemoContent.showcaseProducts)
        if (!_products.any((item) => item.id == sample.id)) sample,
    ];
    final services = [
      for (final sample in DemoContent.showcaseExperiences)
        if (!_services.any((item) => item.id == sample.id)) sample,
    ];
    if (products.isNotEmpty || services.isNotEmpty) {
      _products = [..._products, ...products];
      _services = [..._services, ...services];
      await _persistCatalog();
    }
  }

  /// Versión del piloto: borra de esta instalación los talleres, piezas,
  /// experiencias, reservas, pedidos, comisiones y avisos de ejemplo que
  /// hubieran quedado de versiones anteriores. Lo creado por talleres y
  /// usuarios reales no se toca (sus ids nunca coinciden con los de ejemplo).
  Future<void> _removeSampleData() async {
    if (AppConfig.seedSampleData) return;
    final artisanIds = DemoContent.sampleArtisanIds;
    final productIds = DemoContent.sampleProductIds;
    final experienceIds = DemoContent.sampleExperienceIds;
    final aliasIds = {for (final id in artisanIds) 'u-$id'};

    final artisans = _artisans.length;
    _artisans.removeWhere((artisan) => artisanIds.contains(artisan.id));
    if (_artisans.length != artisans) await _persistArtisans();

    final products = _products.length;
    final services = _services.length;
    _products = [
      for (final product in _products)
        if (!productIds.contains(product.id) &&
            !artisanIds.contains(product.artisanId))
          product,
    ];
    _services = [
      for (final service in _services)
        if (!experienceIds.contains(service.id) &&
            !artisanIds.contains(service.artisanId))
          service,
    ];
    if (_products.length != products || _services.length != services) {
      await _persistCatalog();
    }

    final bookings = _bookings.length;
    _bookings.removeWhere(
      (booking) =>
          _isSeedBooking(booking) || artisanIds.contains(booking.artisanId),
    );
    if (_bookings.length != bookings) await _persistBookings();

    final orders = _orders.length;
    _orders.removeWhere((order) => artisanIds.contains(order.artisanId));
    if (_orders.length != orders) await _persistOrders();

    final ledger = _ledger.length;
    _ledger.removeWhere((entry) => artisanIds.contains(entry.artisanId));
    if (_ledger.length != ledger) await _persistLedger();

    final notifications = _notifications.length;
    _notifications.removeWhere(
      (item) => item.id.startsWith('nt-seed-') || aliasIds.contains(item.userId),
    );
    if (_notifications.length != notifications) await _persistNotifications();
  }

  Future<void> _persistNotifications() async {
    await _store.write(
      _notificationsKey,
      jsonEncode(
        _notifications.map((notification) => notification.toJson()).toList(),
      ),
    );
  }

  String _nextFolio() {
    var max = 1000;
    for (final booking in _bookings) {
      final value = int.tryParse(booking.folio.replaceFirst('BA-', ''));
      if (value != null && value > max) max = value;
    }
    return 'BA-${max + 1}';
  }

  /// Cuenta que administra un taller.
  String? _artisanUserId(String? artisanId) {
    if (artisanId == null) return null;
    final owner = artisanById(artisanId)?.ownerUserId;
    if (owner != null) return owner;
    final current = _user;
    if (current?.artisanId == artisanId) return current?.id;
    // Taller sin cuenta enlazada todavía: el aviso se guarda con su alias y
    // se le entrega cuando inicie sesión (ver _claimDemoData).
    return 'u-$artisanId';
  }

  void _addNotification({
    required String? userId,
    required AppNotificationType type,
    required String title,
    required String body,
    String? bookingId,
  }) {
    if (userId == null) return;
    _notifications.insert(
      0,
      AppNotification(
        id: 'nt-${DateTime.now().microsecondsSinceEpoch}-${_notifications.length}',
        userId: userId,
        type: type,
        title: title,
        body: body,
        bookingId: bookingId,
        createdAt: DateTime.now(),
        delivered: false,
      ),
    );
  }

  Future<void> _notifyStatusChange(Booking booking) async {
    final current = _user;
    final actorIsArtisan = current?.role == UserRole.artisan;
    final recipient = actorIsArtisan
        ? booking.touristId
        : _artisanUserId(booking.artisanId);

    final (type, title, body) = switch (booking.status) {
      BookingStatus.requested => (
        AppNotificationType.newBooking,
        'Nueva solicitud de ${booking.touristName}',
        booking.serviceTitle,
      ),
      BookingStatus.accepted => (
        AppNotificationType.accepted,
        'Reservación confirmada',
        '${booking.serviceTitle} · ${booking.timeSlot}. Te esperamos.',
      ),
      BookingStatus.rejected => (
        AppNotificationType.rejected,
        'Reservación rechazada',
        'El taller no puede recibir la visita del ${booking.date.day}/${booking.date.month}.',
      ),
      BookingStatus.completed => (
        AppNotificationType.completed,
        'Visita completada',
        '${booking.serviceTitle} · ${booking.people} personas.',
      ),
      BookingStatus.cancelledByTourist => (
        AppNotificationType.cancelled,
        'El turista canceló su visita',
        '${booking.serviceTitle} · ${booking.touristName}.',
      ),
      BookingStatus.cancelledByArtisan => (
        AppNotificationType.cancelled,
        'El taller canceló la visita',
        'Se devolverá el anticipo de ${booking.depositAmount} MXN.',
      ),
      BookingStatus.noShow => (
        AppNotificationType.noShow,
        'Registro de no-show',
        '${booking.touristName} no se presentó a ${booking.serviceTitle}.',
      ),
    };

    _addNotification(
      userId: recipient,
      type: type,
      title: title,
      body: body,
      bookingId: booking.id,
    );
    await _persistNotifications();
  }
}

enum ProfileTaskKind {
  photo,
  cover,
  story,
  contact,
  schedule,
  product,
  service,
}

/// Paso de la lista "Completa tu taller".
class ProfileTask {
  const ProfileTask(this.kind, this.label, this.done);

  final ProfileTaskKind kind;
  final String label;
  final bool done;
}

/// Cifras generales de la plataforma.
class PlatformStats {
  const PlatformStats({
    required this.publishedArtisans,
    required this.activeProducts,
    required this.totalProducts,
    required this.activeServices,
    required this.totalServices,
    required this.ordersOpen,
    required this.ordersPendingAcceptance,
    required this.ordersDelivered,
    required this.ordersCancelled,
    required this.bookingsRequested,
    required this.bookingsConfirmed,
    required this.bookingsCompleted,
  });

  final int publishedArtisans;
  final int activeProducts;
  final int totalProducts;
  final int activeServices;
  final int totalServices;
  final int ordersOpen;
  final int ordersPendingAcceptance;
  final int ordersDelivered;
  final int ordersCancelled;
  final int bookingsRequested;
  final int bookingsConfirmed;
  final int bookingsCompleted;
}

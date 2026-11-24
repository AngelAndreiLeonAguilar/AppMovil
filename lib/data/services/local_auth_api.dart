import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/config/app_config.dart';
import '../../domain/artisan_application.dart';
import '../../domain/user.dart';
import '../../domain/user_account.dart';
import 'api_client.dart';
import 'auth_api.dart';
import 'local_store.dart';

/// Autenticación que vive completa en el teléfono.
///
/// Sustituye al backend mientras no hay servidor: guarda cuentas, sesiones,
/// solicitudes de taller y bitácora en el almacenamiento local, con las mismas
/// reglas que la API real (correo único, contraseñas con sal y hash, cuentas
/// suspendidas, revisión de talleres por la administración).
///
/// Cuando exista el servidor basta con compilar con
/// `--dart-define=API_BASE_URL=...` para volver a [HttpAuthApi].
class LocalAuthApi implements AuthApi {
  LocalAuthApi(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  static const _key = 'local.auth.v1';

  final LocalStore _store;
  final DateTime Function() _clock;
  final Random _random = Random.secure();

  final List<_Account> _accounts = [];
  final List<_Application> _applications = [];
  final List<Map<String, dynamic>> _audit = [];
  final Map<String, _Token> _tokens = {};
  int _nextUserId = 1;
  int _nextApplicationId = 1;

  // ---------------------------------------------------------------------------
  // Persistencia
  // ---------------------------------------------------------------------------

  /// Vuelve a leer lo guardado (otro teléfono pudo cambiarlo).
  Future<void> _sync() async {
    await _store.refresh();
    _load();
  }

  void _load() {
    _accounts.clear();
    _applications.clear();
    _audit.clear();
    _tokens.clear();
    final raw = _store.read(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _accounts.addAll(
          (json['accounts'] as List<dynamic>).map(
            (item) => _Account.fromJson(item as Map<String, dynamic>),
          ),
        );
        _applications.addAll(
          (json['applications'] as List<dynamic>).map(
            (item) => _Application.fromJson(item as Map<String, dynamic>),
          ),
        );
        _audit.addAll(
          (json['audit'] as List<dynamic>? ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        (json['tokens'] as Map<String, dynamic>? ?? const {}).forEach(
          (key, value) =>
              _tokens[key] = _Token.fromJson(value as Map<String, dynamic>),
        );
        _nextUserId = json['nextUserId'] as int? ?? _accounts.length + 1;
        _nextApplicationId =
            json['nextApplicationId'] as int? ?? _applications.length + 1;
        _removeSampleAccounts();
        return;
      } catch (_) {
        // Datos dañados: se empieza de cero con las cuentas de prueba.
        _accounts.clear();
        _applications.clear();
        _audit.clear();
        _tokens.clear();
      }
    }
    if (AppConfig.seedDemoAccounts) _seedDemoAccounts();
  }

  /// Versión del piloto: borra las cuentas de prueba (artesana y turista) que
  /// hubieran quedado de versiones anteriores, con sus sesiones y solicitudes.
  void _removeSampleAccounts() {
    if (AppConfig.seedSampleData) return;
    final emails = AppConfig.sampleAccountEmails;
    final removed = {
      for (final account in _accounts)
        if (emails.contains(account.email)) account.id,
    };
    if (removed.isEmpty) return;
    _accounts.removeWhere((account) => removed.contains(account.id));
    _applications.removeWhere((item) => removed.contains(item.userId));
    _tokens.removeWhere((_, token) => removed.contains(token.userId));
    _persist();
  }

  void _seedDemoAccounts() {
    for (final demo in AppConfig.demoAccounts) {
      final salt = _salt();
      _accounts.add(
        _Account(
          id: _nextUserId++,
          nombre: demo.name,
          email: demo.email,
          salt: salt,
          hash: _hash(demo.password, salt),
          role: demo.role,
          artisanId: demo.artisanId,
          estado: 'activo',
          creadoEn: _clock(),
        ),
      );
    }
    _persist();
  }

  Future<void> _persist() => _store.write(
    _key,
    jsonEncode({
      'accounts': _accounts.map((account) => account.toJson()).toList(),
      'applications': _applications.map((item) => item.toJson()).toList(),
      'audit': _audit.take(200).toList(),
      'tokens': _tokens.map((key, value) => MapEntry(key, value.toJson())),
      'nextUserId': _nextUserId,
      'nextApplicationId': _nextApplicationId,
    }),
  );

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  String _salt() =>
      base64Url.encode(List<int>.generate(16, (_) => _random.nextInt(256)));

  String _hash(String password, String salt) {
    List<int> digest = utf8.encode('$salt:$password');
    // Varias vueltas para que un respaldo filtrado no se pueda revertir fácil.
    for (var i = 0; i < 2000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  String _newToken() =>
      base64Url.encode(List<int>.generate(24, (_) => _random.nextInt(256)));

  _Account? _byEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in _accounts) {
      if (account.email == normalized) return account;
    }
    return null;
  }

  _Account? _byId(int id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  User _user(_Account account) => User(
    id: account.id.toString(),
    role: account.role,
    name: account.nombre,
    email: account.email,
    phone: account.telefono,
    artisanId: account.role == UserRole.artisan
        ? (account.artisanId ?? 'art-u${account.id}')
        : null,
  );

  Future<AuthSession> _session(_Account account) async {
    final access = _newToken();
    final refresh = _newToken();
    final now = _clock();
    _tokens[access] = _Token(
      userId: account.id,
      expires: now.add(const Duration(days: 30)),
    );
    _tokens[refresh] = _Token(
      userId: account.id,
      expires: now.add(const Duration(days: 90)),
      refresh: true,
    );
    _tokens.removeWhere((_, token) => token.expires.isBefore(now));
    await _persist();
    return AuthSession(
      user: _user(account),
      accessToken: access,
      refreshToken: refresh,
    );
  }

  _Account _require(String token, {bool refresh = false}) {
    final entry = _tokens[token];
    if (entry == null ||
        entry.refresh != refresh ||
        entry.expires.isBefore(_clock())) {
      throw ApiException(401, 'Tu sesión expiró. Vuelve a iniciar sesión.');
    }
    final account = _byId(entry.userId);
    if (account == null) {
      throw ApiException(401, 'La cuenta ya no existe.');
    }
    if (account.estado != 'activo') {
      throw ApiException(
        403,
        'Tu cuenta está suspendida. Escribe a ${AppConfig.email}.',
      );
    }
    return account;
  }

  _Account _requireAdmin(String token) {
    final account = _require(token);
    if (account.role != UserRole.admin) {
      throw ApiException(403, 'Solo la administración puede hacer esto.');
    }
    return account;
  }

  void _log(String action, String entity, int entityId, {int? actorId}) {
    _audit.insert(0, {
      'accion': action,
      'entidad': entity,
      'entidad_id': entityId,
      'actor_id': ?actorId,
      'creado_en': _clock().toIso8601String().replaceFirst('T', ' ').substring(
        0,
        19,
      ),
    });
  }

  ArtisanApplication _toApplication(_Application item) => ArtisanApplication(
    id: item.id,
    nombreTaller: item.nombreTaller,
    estado: item.estado,
    motivoRechazo: item.motivo,
    notasRevision: item.notas,
    creadoEn: item.creadoEn,
    descripcion: item.descripcion,
    ubicacion: item.ubicacion,
    direccion: item.direccion,
    telefono: item.telefono,
    oficio: item.oficio,
  );

  ArtisanApplication? _applicationOf(int userId) {
    _Application? latest;
    for (final item in _applications) {
      if (item.userId == userId &&
          (latest == null || item.id > latest.id)) {
        latest = item;
      }
    }
    return latest == null ? null : _toApplication(latest);
  }

  // ---------------------------------------------------------------------------
  // AuthApi
  // ---------------------------------------------------------------------------

  @override
  Future<void> ping() async {}

  @override
  Future<AuthSession> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    await _sync();
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw ApiException(422, 'Escribe un correo válido.');
    }
    if (password.length < 8) {
      throw ApiException(422, 'La contraseña debe tener mínimo 8 caracteres.');
    }
    if (_byEmail(normalized) != null) {
      throw ApiException(
        409,
        'Ese correo ya tiene una cuenta. Inicia sesión con él.',
      );
    }
    final salt = _salt();
    final account = _Account(
      id: _nextUserId++,
      nombre: nombre.trim(),
      email: normalized,
      salt: salt,
      hash: _hash(password, salt),
      role: UserRole.tourist,
      telefono: telefono?.trim(),
      estado: 'activo',
      creadoEn: _clock(),
    );
    _accounts.add(account);
    _log('usuario_registrado', 'usuarios', account.id, actorId: account.id);
    return _session(account);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await _sync();
    final account = _byEmail(email);
    if (account == null || account.hash != _hash(password, account.salt)) {
      throw ApiException(401, 'Correo o contraseña incorrectos.');
    }
    if (account.estado != 'activo') {
      throw ApiException(
        403,
        'Tu cuenta está suspendida. Escribe a ${AppConfig.email}.',
      );
    }
    return _session(account);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    await _sync();
    final account = _require(refreshToken, refresh: true);
    _tokens.remove(refreshToken);
    return _session(account);
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _sync();
    _tokens.remove(accessToken);
    _tokens.remove(refreshToken);
    await _persist();
  }

  @override
  Future<MeResponse> me(String accessToken) async {
    await _sync();
    final account = _require(accessToken);
    return MeResponse(
      user: _user(account),
      application: _applicationOf(account.id),
      unreadNotifications: 0,
    );
  }

  @override
  Future<User> updateAccount(
    String accessToken, {
    String? nombre,
    String? telefono,
  }) async {
    await _sync();
    final account = _require(accessToken);
    if (nombre != null) {
      if (nombre.trim().length < 3) {
        throw ApiException(422, 'Escribe tu nombre completo.');
      }
      account.nombre = nombre.trim();
    }
    if (telefono != null) account.telefono = telefono.trim();
    await _persist();
    return _user(account);
  }

  @override
  Future<void> changePassword(
    String accessToken, {
    required String current,
    required String next,
  }) async {
    await _sync();
    final account = _require(accessToken);
    if (account.hash != _hash(current, account.salt)) {
      throw ApiException(401, 'La contraseña actual no es correcta.');
    }
    if (next.length < 8) {
      throw ApiException(422, 'La nueva contraseña necesita 8 caracteres.');
    }
    account.salt = _salt();
    account.hash = _hash(next, account.salt);
    _log('contrasena_cambiada', 'usuarios', account.id, actorId: account.id);
    await _persist();
  }

  @override
  Future<ArtisanApplication?> myApplication(String accessToken) async {
    await _sync();
    final account = _require(accessToken);
    return _applicationOf(account.id);
  }

  @override
  Future<ArtisanApplication> submitApplication(
    String accessToken, {
    required String nombreTaller,
    required String descripcion,
    String? ubicacion,
    String? direccion,
    String? telefono,
    String? oficio,
  }) async {
    await _sync();
    final account = _require(accessToken);
    if (account.role != UserRole.tourist) {
      throw ApiException(409, 'Tu cuenta ya es de taller.');
    }
    final open = _applications.any(
      (item) =>
          item.userId == account.id &&
          (item.estado == 'pendiente' || item.estado == 'en_revision'),
    );
    if (open) throw ApiException(409, 'Ya tienes una solicitud en revisión.');

    final application = _Application(
      id: _nextApplicationId++,
      userId: account.id,
      nombreTaller: nombreTaller.trim(),
      descripcion: descripcion.trim(),
      ubicacion: ubicacion,
      direccion: direccion,
      telefono: telefono,
      oficio: oficio,
      estado: 'pendiente',
      creadoEn: _clock(),
    );
    _applications.add(application);
    _log(
      'solicitud_enviada',
      'solicitudes_artesano',
      application.id,
      actorId: account.id,
    );

    if (AppConfig.autoApproveArtisans) {
      application.estado = 'aprobada';
      application.notas = 'Aprobada automáticamente (modo de pruebas).';
      account.role = UserRole.artisan;
      account.artisanId ??= 'art-u${account.id}';
      _log('solicitud_aprobada', 'solicitudes_artesano', application.id);
    }
    await _persist();
    return _toApplication(application);
  }

  @override
  Future<List<ArtisanApplication>> listApplications(
    String accessToken, {
    String? estado,
  }) async {
    await _sync();
    _requireAdmin(accessToken);
    final list = [
      for (final item in _applications)
        if (estado == null || item.estado == estado) _toApplication(item),
    ];
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  @override
  Future<ArtisanApplication> reviewApplication(
    String accessToken,
    int applicationId, {
    required String decision,
    String? motivo,
    String? notas,
  }) async {
    await _sync();
    final admin = _requireAdmin(accessToken);
    final application = _applications
        .where((item) => item.id == applicationId)
        .firstOrNull;
    if (application == null) {
      throw ApiException(404, 'No se encontró la solicitud.');
    }
    if (application.userId == admin.id) {
      throw ApiException(403, 'No puedes revisar tu propia solicitud.');
    }
    if (decision == 'rechazada' && (motivo == null || motivo.trim().length < 5)) {
      throw ApiException(422, 'Escribe el motivo del rechazo.');
    }
    application.estado = decision;
    application.motivo = motivo;
    application.notas = notas;
    final owner = _byId(application.userId);
    if (decision == 'aprobada' && owner != null) {
      owner.role = UserRole.artisan;
      owner.artisanId ??= 'art-u${owner.id}';
    }
    _log(
      'solicitud_$decision',
      'solicitudes_artesano',
      application.id,
      actorId: admin.id,
    );
    await _persist();
    return _toApplication(application);
  }

  @override
  Future<List<UserAccount>> listUsers(String accessToken, {String? rol}) async {
    await _sync();
    _requireAdmin(accessToken);
    final wanted = rol == null ? null : roleFromApi(rol);
    return [
      for (final account in _accounts)
        if (wanted == null || account.role == wanted)
          UserAccount(
            id: account.id,
            nombre: account.nombre,
            email: account.email,
            role: account.role,
            estado: account.estado,
            telefono: account.telefono,
          ),
    ];
  }

  @override
  Future<void> suspendUser(String accessToken, int userId, String motivo) async {
    await _sync();
    final admin = _requireAdmin(accessToken);
    if (userId == admin.id) {
      throw ApiException(409, 'No puedes suspender tu propia cuenta.');
    }
    final target = _byId(userId);
    if (target == null) throw ApiException(404, 'Usuario no encontrado.');
    if (target.role == UserRole.admin) {
      throw ApiException(403, 'No puedes suspender a otro administrador.');
    }
    target.estado = 'suspendido';
    _tokens.removeWhere((_, token) => token.userId == userId);
    _log('usuario_suspendido', 'usuarios', userId, actorId: admin.id);
    await _persist();
  }

  @override
  Future<void> reactivateUser(String accessToken, int userId) async {
    await _sync();
    final admin = _requireAdmin(accessToken);
    final target = _byId(userId);
    if (target == null) throw ApiException(404, 'Usuario no encontrado.');
    target.estado = 'activo';
    _log('usuario_reactivado', 'usuarios', userId, actorId: admin.id);
    await _persist();
  }

  @override
  Future<List<Map<String, dynamic>>> auditLog(String accessToken) async {
    await _sync();
    _requireAdmin(accessToken);
    return List<Map<String, dynamic>>.from(_audit);
  }

  @override
  Future<Map<String, int>> adminSummary(String accessToken) async {
    await _sync();
    _requireAdmin(accessToken);
    return {
      'usuarios': _accounts.length,
      'talleres': _accounts
          .where((account) => account.role == UserRole.artisan)
          .length,
      'solicitudes_pendientes': _applications
          .where((item) => item.estado == 'pendiente')
          .length,
      'solicitudes_totales': _applications.length,
    };
  }
}

class _Account {
  _Account({
    required this.id,
    required this.nombre,
    required this.email,
    required this.salt,
    required this.hash,
    required this.role,
    required this.estado,
    required this.creadoEn,
    this.telefono,
    this.artisanId,
  });

  final int id;
  String nombre;
  final String email;
  String salt;
  String hash;
  UserRole role;
  String estado;
  String? telefono;
  String? artisanId;
  final DateTime creadoEn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'salt': salt,
    'hash': hash,
    'role': role.name,
    'estado': estado,
    'telefono': telefono,
    'artisanId': artisanId,
    'creadoEn': creadoEn.toIso8601String(),
  };

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    salt: json['salt'] as String,
    hash: json['hash'] as String,
    role: UserRole.values.firstWhere(
      (role) => role.name == json['role'],
      orElse: () => UserRole.tourist,
    ),
    estado: json['estado'] as String? ?? 'activo',
    telefono: json['telefono'] as String?,
    artisanId: json['artisanId'] as String?,
    creadoEn:
        DateTime.tryParse(json['creadoEn'] as String? ?? '') ?? DateTime.now(),
  );
}

class _Application {
  _Application({
    required this.id,
    required this.userId,
    required this.nombreTaller,
    required this.descripcion,
    required this.estado,
    required this.creadoEn,
    this.ubicacion,
    this.direccion,
    this.telefono,
    this.oficio,
  });

  final int id;
  final int userId;
  final String nombreTaller;
  final String descripcion;
  final String? ubicacion;
  final String? direccion;
  final String? telefono;
  final String? oficio;
  String estado;
  String? motivo;
  String? notas;
  final DateTime creadoEn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'nombreTaller': nombreTaller,
    'descripcion': descripcion,
    'ubicacion': ubicacion,
    'direccion': direccion,
    'telefono': telefono,
    'oficio': oficio,
    'estado': estado,
    'motivo': motivo,
    'notas': notas,
    'creadoEn': creadoEn.toIso8601String(),
  };

  factory _Application.fromJson(Map<String, dynamic> json) =>
      _Application(
          id: json['id'] as int,
          userId: json['userId'] as int,
          nombreTaller: json['nombreTaller'] as String,
          descripcion: json['descripcion'] as String? ?? '',
          ubicacion: json['ubicacion'] as String?,
          direccion: json['direccion'] as String?,
          telefono: json['telefono'] as String?,
          oficio: json['oficio'] as String?,
          estado: json['estado'] as String? ?? 'pendiente',
          creadoEn:
              DateTime.tryParse(json['creadoEn'] as String? ?? '') ??
              DateTime.now(),
        )
        ..motivo = json['motivo'] as String?
        ..notas = json['notas'] as String?;
}

class _Token {
  const _Token({
    required this.userId,
    required this.expires,
    this.refresh = false,
  });

  final int userId;
  final DateTime expires;
  final bool refresh;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'expires': expires.toIso8601String(),
    'refresh': refresh,
  };

  factory _Token.fromJson(Map<String, dynamic> json) => _Token(
    userId: json['userId'] as int,
    expires: DateTime.parse(json['expires'] as String),
    refresh: json['refresh'] as bool? ?? false,
  );
}

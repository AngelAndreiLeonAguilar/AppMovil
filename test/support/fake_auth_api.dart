import 'package:bel_aaktun/data/services/api_client.dart';
import 'package:bel_aaktun/data/services/auth_api.dart';
import 'package:bel_aaktun/domain/artisan_application.dart';
import 'package:bel_aaktun/domain/user.dart';
import 'package:bel_aaktun/domain/user_account.dart';

/// API en memoria que imita al backend real para las pruebas de widget.
class FakeAuthApi implements AuthApi {
  FakeAuthApi() {
    _addUser(
      id: 1,
      nombre: 'Administración',
      email: 'admin@test.mx',
      password: 'Clave1234',
      role: UserRole.admin,
    );
    _addUser(
      id: 2,
      nombre: 'Ana Canul',
      email: 'turista@test.mx',
      password: 'Clave1234',
      role: UserRole.tourist,
    );
    _addUser(
      id: 3,
      nombre: 'Doña Elena Chan',
      email: 'elena@test.mx',
      password: 'Clave1234',
      role: UserRole.artisan,
      artisanId: 'art-01',
    );
    _addUser(
      id: 4,
      nombre: 'Taller en trámite',
      email: 'pendiente@test.mx',
      password: 'Clave1234',
      role: UserRole.tourist,
    );
    _applications.add(
      _App(
        id: 1,
        userId: 4,
        nombreTaller: 'Cueva en trámite',
        estado: 'pendiente',
        creadoEn: DateTime(2026, 11, 1),
      ),
    );
  }

  final Map<String, _Account> _accounts = {};
  final List<_App> _applications = [];
  final List<Map<String, dynamic>> _audit = [];
  final Map<String, int> _tokens = {};
  int _nextUserId = 10;
  int _nextToken = 1;

  void _addUser({
    required int id,
    required String nombre,
    required String email,
    required String password,
    required UserRole role,
    String? artisanId,
  }) {
    _accounts[email] = _Account(
      id: id,
      nombre: nombre,
      email: email,
      password: password,
      role: role,
      artisanId: artisanId,
    );
  }

  _Account? _accountById(int id) =>
      _accounts.values.where((account) => account.id == id).firstOrNull;

  _Account? _accountByEmail(String email) =>
      _accounts[email.trim().toLowerCase()];

  User _user(_Account account) => User(
    id: account.id.toString(),
    role: account.role,
    name: account.nombre,
    email: account.email,
    artisanId: account.role == UserRole.artisan
        ? (account.artisanId ?? 'art-u${account.id}')
        : null,
  );

  AuthSession _session(_Account account) {
    final access = 'access-${account.id}-${_nextToken++}';
    final refresh = 'refresh-${account.id}-${_nextToken++}';
    _tokens[access] = account.id;
    _tokens[refresh] = account.id;
    return AuthSession(
      user: _user(account),
      accessToken: access,
      refreshToken: refresh,
    );
  }

  _Account _require(String token) {
    final id = _tokens[token];
    final account = id == null ? null : _accountById(id);
    if (account == null) {
      throw ApiException(401, 'Sesión inválida.');
    }
    if (account.estado != 'activo') {
      throw ApiException(403, 'La cuenta está suspendida.');
    }
    return account;
  }

  @override
  Future<AuthSession> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_accounts.containsKey(normalized)) {
      throw ApiException(409, 'Ese correo ya está registrado.');
    }
    final account = _Account(
      id: _nextUserId++,
      nombre: nombre,
      email: normalized,
      password: password,
      role: UserRole.tourist,
      telefono: telefono,
    );
    _accounts[normalized] = account;
    _audit.insert(0, {
      'accion': 'usuario_registrado',
      'entidad': 'usuarios',
      'entidad_id': account.id,
      'creado_en': '2026-11-03 10:00:00',
    });
    return _session(account);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final account = _accountByEmail(email);
    if (account == null || account.password != password) {
      throw ApiException(401, 'Correo o contraseña incorrectos.');
    }
    if (account.estado != 'activo') {
      throw ApiException(403, 'La cuenta está suspendida.');
    }
    return _session(account);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final account = _require(refreshToken);
    _tokens.remove(refreshToken);
    return _session(account);
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    _tokens.remove(accessToken);
    _tokens.remove(refreshToken);
  }

  @override
  Future<MeResponse> me(String accessToken) async {
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
    final account = _require(accessToken);
    if (nombre != null) account.nombre = nombre;
    return _user(account);
  }

  @override
  Future<void> changePassword(
    String accessToken, {
    required String current,
    required String next,
  }) async {
    final account = _require(accessToken);
    if (account.password != current) {
      throw ApiException(401, 'La contraseña actual no es correcta.');
    }
    account.password = next;
  }

  @override
  Future<ArtisanApplication?> myApplication(String accessToken) async {
    final account = _require(accessToken);
    return _applicationOf(account.id);
  }

  ArtisanApplication? _applicationOf(int userId) {
    final application = _applications
        .where((item) => item.userId == userId)
        .firstOrNull;
    return application == null
        ? null
        : ArtisanApplication(
            id: application.id,
            nombreTaller: application.nombreTaller,
            estado: application.estado,
            motivoRechazo: application.motivo,
            creadoEn: application.creadoEn,
          );
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
    final account = _require(accessToken);
    if (account.role != UserRole.tourist) {
      throw ApiException(409, 'Tu cuenta ya es de taller.');
    }
    final existing = _applications
        .where(
          (item) =>
              item.userId == account.id &&
              (item.estado == 'pendiente' || item.estado == 'en_revision'),
        )
        .firstOrNull;
    if (existing != null) {
      throw ApiException(409, 'Ya tienes una solicitud abierta.');
    }
    final application = _App(
      id: _applications.length + 1,
      userId: account.id,
      nombreTaller: nombreTaller,
      estado: 'pendiente',
      creadoEn: DateTime(2026, 11, 3),
    );
    _applications.add(application);
    _audit.insert(0, {
      'accion': 'solicitud_enviada',
      'entidad': 'solicitudes_artesano',
      'entidad_id': application.id,
      'creado_en': '2026-11-03 10:05:00',
    });
    return _applicationOf(account.id)!;
  }

  @override
  Future<List<ArtisanApplication>> listApplications(
    String accessToken, {
    String? estado,
  }) async {
    final account = _require(accessToken);
    if (account.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    return [
      for (final application in _applications)
        if (estado == null || application.estado == estado)
          ArtisanApplication(
            id: application.id,
            nombreTaller: application.nombreTaller,
            estado: application.estado,
            motivoRechazo: application.motivo,
            creadoEn: application.creadoEn,
          ),
    ];
  }

  @override
  Future<ArtisanApplication> reviewApplication(
    String accessToken,
    int applicationId, {
    required String decision,
    String? motivo,
    String? notas,
  }) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    final application = _applications
        .where((item) => item.id == applicationId)
        .firstOrNull;
    if (application == null) {
      throw ApiException(404, 'Solicitud no encontrada.');
    }
    if (application.userId == admin.id) {
      throw ApiException(403, 'No puedes revisar tu propia solicitud.');
    }
    if (decision == 'rechazada' && (motivo == null || motivo.length < 5)) {
      throw ApiException(422, 'Escribe el motivo del rechazo.');
    }
    application.estado = decision;
    application.motivo = motivo;
    if (decision == 'aprobada') {
      _accountById(application.userId)?.role = UserRole.artisan;
    }
    _audit.insert(0, {
      'accion': 'solicitud_$decision',
      'entidad': 'solicitudes_artesano',
      'entidad_id': application.id,
      'creado_en': '2026-11-03 10:10:00',
    });
    return ArtisanApplication(
      id: application.id,
      nombreTaller: application.nombreTaller,
      estado: application.estado,
      motivoRechazo: application.motivo,
      creadoEn: application.creadoEn,
    );
  }

  @override
  Future<List<UserAccount>> listUsers(
    String accessToken, {
    String? rol,
  }) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    return [
      for (final account in _accounts.values)
        if (rol == null ||
            (rol == 'artesano' && account.role == UserRole.artisan) ||
            (rol == 'turista' && account.role == UserRole.tourist) ||
            (rol == 'admin' && account.role == UserRole.admin))
          UserAccount(
            id: account.id,
            nombre: account.nombre,
            email: account.email,
            role: account.role,
            estado: account.estado,
          ),
    ];
  }

  @override
  Future<void> suspendUser(
    String accessToken,
    int userId,
    String motivo,
  ) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    if (userId == admin.id) {
      throw ApiException(409, 'No puedes suspender tu propia cuenta.');
    }
    final target = _accountById(userId);
    if (target == null) throw ApiException(404, 'Usuario no encontrado.');
    if (target.role == UserRole.admin) {
      throw ApiException(403, 'No puedes suspender a otro administrador.');
    }
    target.estado = 'suspendido';
    _audit.insert(0, {
      'accion': 'usuario_suspendido',
      'entidad': 'usuarios',
      'entidad_id': userId,
      'creado_en': '2026-11-03 10:20:00',
    });
  }

  @override
  Future<void> reactivateUser(String accessToken, int userId) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    final target = _accountById(userId);
    if (target == null) throw ApiException(404, 'Usuario no encontrado.');
    target.estado = 'activo';
    _audit.insert(0, {
      'accion': 'usuario_reactivado',
      'entidad': 'usuarios',
      'entidad_id': userId,
      'creado_en': '2026-11-03 10:25:00',
    });
  }

  @override
  Future<List<Map<String, dynamic>>> auditLog(String accessToken) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    return List<Map<String, dynamic>>.from(_audit);
  }

  @override
  Future<Map<String, int>> adminSummary(String accessToken) async {
    final admin = _require(accessToken);
    if (admin.role != UserRole.admin) {
      throw ApiException(403, 'Sin permiso.');
    }
    return {
      'usuarios': _accounts.length,
      'talleres': _accounts.values
          .where((account) => account.role == UserRole.artisan)
          .length,
      'solicitudes_pendientes': _applications
          .where((item) => item.estado == 'pendiente')
          .length,
      'solicitudes_totales': _applications.length,
    };
  }

  @override
  Future<void> ping() async {}
}

class _Account {
  _Account({
    required this.id,
    required this.nombre,
    required this.email,
    required this.password,
    required this.role,
    this.telefono,
    this.artisanId,
  });

  final int id;
  String nombre;
  final String email;
  String password;
  UserRole role;
  String estado = 'activo';
  final String? telefono;
  final String? artisanId;
}

class _App {
  _App({
    required this.id,
    required this.userId,
    required this.nombreTaller,
    required this.estado,
    required this.creadoEn,
  });

  final int id;
  final int userId;
  final String nombreTaller;
  String estado;
  String? motivo;
  final DateTime creadoEn;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

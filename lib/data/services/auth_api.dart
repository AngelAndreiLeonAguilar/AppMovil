import '../../domain/artisan_application.dart';
import '../../domain/user.dart';
import '../../domain/user_account.dart';
import 'api_client.dart';

/// Sesión autenticada contra la API.
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final User user;
  final String accessToken;
  final String refreshToken;
}

/// Perfil + estado de solicitud que devuelve `/auth/me`.
class MeResponse {
  const MeResponse({
    required this.user,
    required this.application,
    required this.unreadNotifications,
  });

  final User user;
  final ArtisanApplication? application;
  final int unreadNotifications;
}

/// Contrato de autenticación y verificación.
///
/// La app solo habla con esta interfaz; en pruebas se usa una implementación
/// falsa, en producción [HttpAuthApi].
abstract interface class AuthApi {
  Future<AuthSession> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> refresh(String refreshToken);

  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  });

  Future<MeResponse> me(String accessToken);

  Future<ArtisanApplication?> myApplication(String accessToken);

  /// Actualiza nombre o teléfono de la cuenta.
  Future<User> updateAccount(
    String accessToken, {
    String? nombre,
    String? telefono,
  });

  Future<void> changePassword(
    String accessToken, {
    required String current,
    required String next,
  });

  Future<ArtisanApplication> submitApplication(
    String accessToken, {
    required String nombreTaller,
    required String descripcion,
    String? ubicacion,
    String? direccion,
    String? telefono,
    String? oficio,
  });

  Future<List<ArtisanApplication>> listApplications(
    String accessToken, {
    String? estado,
  });

  Future<ArtisanApplication> reviewApplication(
    String accessToken,
    int applicationId, {
    required String decision,
    String? motivo,
    String? notas,
  });

  Future<List<UserAccount>> listUsers(String accessToken, {String? rol});

  Future<void> suspendUser(String accessToken, int userId, String motivo);

  Future<void> reactivateUser(String accessToken, int userId);

  Future<List<Map<String, dynamic>>> auditLog(String accessToken);

  Future<Map<String, int>> adminSummary(String accessToken);

  /// Comprueba que el servidor responda (`/health`).
  Future<void> ping();
}

/// Implementación HTTP real.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({required this.client});

  final ApiClient client;

  User _userFromJson(Map<String, dynamic> json) {
    final role = roleFromApi(json['rol']?.toString());
    final id = json['id'].toString();
    final tallerId = json['taller_id'];
    String? artisanId;
    if (role == UserRole.artisan) {
      artisanId = tallerId != null ? 'art-$tallerId' : 'art-u$id';
    }
    return User(
      id: id,
      role: role,
      name: json['nombre'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['telefono'] as String?,
      artisanId: artisanId,
    );
  }

  AuthSession _session(Map<String, dynamic> json) => AuthSession(
    user: _userFromJson(json['user'] as Map<String, dynamic>),
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );

  @override
  Future<AuthSession> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final json = await client.post(
      '/auth/register',
      body: {
        'nombre': nombre,
        'email': email,
        'password': password,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      },
    );
    return _session(json);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _session(json);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final json = await client.post(
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    return _session(json);
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    await client.post(
      '/auth/logout',
      token: accessToken,
      body: {'refresh_token': refreshToken},
    );
  }

  @override
  Future<MeResponse> me(String accessToken) async {
    final json = await client.get('/auth/me', token: accessToken);
    return MeResponse(
      user: _userFromJson(json['user'] as Map<String, dynamic>),
      application: ArtisanApplication.fromJson(
        json['solicitud'] as Map<String, dynamic>?,
      ),
      unreadNotifications: (json['notificaciones_no_leidas'] as int?) ?? 0,
    );
  }

  @override
  Future<ArtisanApplication?> myApplication(String accessToken) async {
    final json = await client.get(
      '/artisan-applications/me',
      token: accessToken,
    );
    return ArtisanApplication.fromJson(
      json['solicitud'] as Map<String, dynamic>?,
    );
  }

  @override
  Future<User> updateAccount(
    String accessToken, {
    String? nombre,
    String? telefono,
  }) async {
    final json = await client.post(
      '/auth/me',
      token: accessToken,
      body: {
        'nombre': ?nombre,
        'telefono': ?telefono,
      },
    );
    return _userFromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword(
    String accessToken, {
    required String current,
    required String next,
  }) async {
    await client.post(
      '/auth/password',
      token: accessToken,
      body: {'actual': current, 'nueva': next},
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
    final json = await client.post(
      '/artisan-applications',
      token: accessToken,
      body: {
        'nombre_taller': nombreTaller,
        'descripcion': descripcion,
        if (ubicacion != null && ubicacion.isNotEmpty) 'ubicacion': ubicacion,
        if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
        if (telefono != null && telefono.isNotEmpty)
          'telefono_contacto': telefono,
        if (oficio != null && oficio.isNotEmpty) 'oficio': oficio,
      },
    );
    return ArtisanApplication.fromJson(
      json['solicitud'] as Map<String, dynamic>,
    )!;
  }

  @override
  Future<List<ArtisanApplication>> listApplications(
    String accessToken, {
    String? estado,
  }) async {
    final query = estado == null ? '' : '?estado=$estado';
    final json = await client.get(
      '/artisan-applications$query',
      token: accessToken,
    );
    final list = (json['solicitudes'] as List<dynamic>? ?? const []);
    return list
        .map(
          (item) => ArtisanApplication.fromJson(item as Map<String, dynamic>)!,
        )
        .toList();
  }

  @override
  Future<ArtisanApplication> reviewApplication(
    String accessToken,
    int applicationId, {
    required String decision,
    String? motivo,
    String? notas,
  }) async {
    final json = await client.post(
      '/artisan-applications/$applicationId/review',
      token: accessToken,
      body: {
        'decision': decision,
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    return ArtisanApplication.fromJson(
      json['solicitud'] as Map<String, dynamic>,
    )!;
  }

  @override
  Future<List<UserAccount>> listUsers(
    String accessToken, {
    String? rol,
  }) async {
    final query = rol == null ? '' : '?rol=$rol';
    final json = await client.get('/admin/users$query', token: accessToken);
    return (json['usuarios'] as List<dynamic>? ?? const [])
        .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> suspendUser(
    String accessToken,
    int userId,
    String motivo,
  ) async {
    await client.post(
      '/admin/users/$userId/suspend',
      token: accessToken,
      body: {'motivo': motivo},
    );
  }

  @override
  Future<void> reactivateUser(String accessToken, int userId) async {
    await client.post('/admin/users/$userId/reactivate', token: accessToken);
  }

  @override
  Future<List<Map<String, dynamic>>> auditLog(String accessToken) async {
    final json = await client.get('/admin/audit', token: accessToken);
    return (json['registro'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  @override
  Future<Map<String, int>> adminSummary(String accessToken) async {
    final json = await client.get('/admin/summary', token: accessToken);
    return {
      'usuarios': (json['usuarios'] as int?) ?? 0,
      'talleres': (json['talleres'] as int?) ?? 0,
      'solicitudes_pendientes': (json['solicitudes_pendientes'] as int?) ?? 0,
      'solicitudes_totales': (json['solicitudes_totales'] as int?) ?? 0,
    };
  }

  @override
  Future<void> ping() async {
    await client.get('/health');
  }
}

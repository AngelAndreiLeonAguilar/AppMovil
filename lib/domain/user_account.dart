import '../../domain/user.dart';

/// Cuenta tal como la ve la administración (incluye estado).
class UserAccount {
  const UserAccount({
    required this.id,
    required this.nombre,
    required this.email,
    required this.role,
    required this.estado,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String email;
  final UserRole role;
  final String estado;
  final String? telefono;

  bool get isSuspended => estado == 'suspendido';

  static UserAccount fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: roleFromApi(json['rol']?.toString()),
    estado: json['estado']?.toString() ?? 'activo',
    telefono: json['telefono'] as String?,
  );
}

/// `turista|artesano|admin` → [UserRole].
UserRole roleFromApi(String? rol) => switch (rol) {
  'artesano' => UserRole.artisan,
  'admin' => UserRole.admin,
  _ => UserRole.tourist,
};

/// Usuarios y roles de Bel-Aaktun.
library;

enum UserRole {
  tourist('Turista'),
  artisan('Artesano'),
  admin('Administrador');

  const UserRole(this.label);

  final String label;
}

/// Usuario autenticado en la app.
///
/// Un artesano guarda también [artisanId] para enlazar su cuenta con su ficha
/// de [`Artisan`] y con sus productos, servicios y reservaciones.
class User {
  const User({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.artisanId,
    this.phone,
  });

  final String id;
  final UserRole role;
  final String name;
  final String email;

  /// Solo para [UserRole.artisan]: id del taller que administra.
  final String? artisanId;

  final String? phone;

  bool get isArtisan => role == UserRole.artisan && artisanId != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'name': name,
    'email': email,
    'artisanId': artisanId,
    'phone': phone,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    role: UserRole.values.firstWhere(
      (role) => role.name == json['role'],
      orElse: () => UserRole.tourist,
    ),
    name: json['name'] as String,
    email: json['email'] as String,
    artisanId: json['artisanId'] as String?,
    phone: json['phone'] as String?,
  );
}

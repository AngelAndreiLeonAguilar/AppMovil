/// Solicitud de verificación de un taller.
class ArtisanApplication {
  const ArtisanApplication({
    required this.id,
    required this.nombreTaller,
    required this.estado,
    this.motivoRechazo,
    this.notasRevision,
    this.creadoEn,
    this.descripcion,
    this.ubicacion,
    this.direccion,
    this.telefono,
    this.oficio,
  });

  final int id;
  final String nombreTaller;
  final String estado; // pendiente | en_revision | aprobada | rechazada | suspendida | retirada
  final String? motivoRechazo;
  final String? notasRevision;
  final DateTime? creadoEn;
  final String? descripcion;
  final String? ubicacion;
  final String? direccion;
  final String? telefono;
  final String? oficio;

  bool get isPending => estado == 'pendiente' || estado == 'en_revision';

  bool get isApproved => estado == 'aprobada';

  bool get isRejected => estado == 'rechazada';

  static ArtisanApplication? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ArtisanApplication(
      id: json['id'] as int,
      nombreTaller: json['nombre_taller'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
      motivoRechazo: json['motivo_rechazo'] as String?,
      notasRevision: json['notas_revision'] as String?,
      creadoEn: DateTime.tryParse(json['creado_en']?.toString() ?? ''),
      descripcion: json['descripcion'] as String?,
      ubicacion: json['ubicacion'] as String?,
      direccion: json['direccion'] as String?,
      telefono: json['telefono_contacto'] as String?,
      oficio: json['oficio'] as String?,
    );
  }
}

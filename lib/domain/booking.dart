/// Reservaciones: estados, historial y serialización.
library;

/// Estado de una reservación.
///
/// Se usa en el panel del artesano y en "Mis reservas" del turista. El orden de
/// los valores no importa: las transiciones se validan en [BookingRules].
enum BookingStatus {
  requested('Solicitud', 'Esperando respuesta del taller'),
  accepted('Confirmada', 'El taller aceptó la visita'),
  rejected('Rechazada', 'El taller no puede recibir la visita'),
  completed('Completada', 'La visita se realizó'),
  cancelledByTourist('Cancelada', 'Cancelada por el turista'),
  cancelledByArtisan('Cancelada por el taller', 'El taller canceló la visita'),
  noShow('No asistió', 'El turista no llegó a la visita');

  const BookingStatus(this.label, this.description);

  final String label;
  final String description;

  bool get isPending => this == BookingStatus.requested;

  bool get isConfirmed => this == BookingStatus.accepted;

  /// Sigue ocupando lugar en la agenda.
  bool get isActive => isPending || isConfirmed;

  bool get isClosed => !isActive;

  /// Cuenta como visita realizada (y por lo tanto como ingreso cobrado).
  bool get isCompleted => this == BookingStatus.completed;
}

/// Estado del anticipo. Mientras no exista pasarela de pago, los anticipos se
/// marcan como [simulatedPaid] y la interfaz los identifica como demo.
enum DepositStatus {
  none('Sin anticipo'),
  simulatedPaid('Se paga en el taller'),
  paid('Pagado'),
  refunded('Reembolsado'),
  partiallyRefunded('Reembolso parcial'),
  forfeited('Retenido');

  const DepositStatus(this.label);

  final String label;
}

/// Una entrada del historial de una reservación.
class BookingEvent {
  const BookingEvent({
    required this.status,
    required this.at,
    this.byRole,
    this.note,
  });

  final BookingStatus status;
  final DateTime at;

  /// Rol que provocó el cambio (`null` en la creación).
  final String? byRole;
  final String? note;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'at': at.toIso8601String(),
    'byRole': byRole,
    'note': note,
  };

  factory BookingEvent.fromJson(Map<String, dynamic> json) => BookingEvent(
    status: BookingStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => BookingStatus.requested,
    ),
    at: DateTime.parse(json['at'] as String),
    byRole: json['byRole'] as String?,
    note: json['note'] as String?,
  );
}

/// Reservación completa, tal como la ve el turista y el artesano.
class Booking {
  const Booking({
    required this.id,
    required this.folio,
    required this.serviceId,
    required this.serviceTitle,
    required this.artisanId,
    required this.touristId,
    required this.touristName,
    required this.touristPhone,
    required this.date,
    required this.timeSlot,
    required this.people,
    required this.status,
    required this.totalAmount,
    required this.depositAmount,
    required this.depositStatus,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.refundAmount = 0,
    this.history = const [],
    this.isDemo = true,
  });

  final String id;
  final String folio;
  final String serviceId;
  final String serviceTitle;
  final String artisanId;
  final String touristId;
  final String touristName;
  final String touristPhone;

  /// Día de la visita (sin hora).
  final DateTime date;
  final String timeSlot;
  final int people;
  final BookingStatus status;

  /// Total en MXN de la visita (`people` × precio por persona).
  final int totalAmount;

  /// Anticipo en MXN. Puede ser 0 si el taller no pide anticipo.
  final int depositAmount;
  final DepositStatus depositStatus;

  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Monto devuelto al turista (MXN). 0 si no aplica reembolso.
  final int refundAmount;

  final List<BookingEvent> history;

  /// Todo el contenido actual es de demostración; los cobros también.
  final bool isDemo;

  int get balance => (totalAmount - depositAmount).clamp(0, totalAmount);

  bool get hasDeposit => depositAmount > 0;

  Booking copyWith({
    BookingStatus? status,
    DepositStatus? depositStatus,
    DateTime? updatedAt,
    int? refundAmount,
    List<BookingEvent>? history,
    String? touristId,
  }) => Booking(
    id: id,
    folio: folio,
    serviceId: serviceId,
    serviceTitle: serviceTitle,
    artisanId: artisanId,
    touristId: touristId ?? this.touristId,
    touristName: touristName,
    touristPhone: touristPhone,
    date: date,
    timeSlot: timeSlot,
    people: people,
    status: status ?? this.status,
    totalAmount: totalAmount,
    depositAmount: depositAmount,
    depositStatus: depositStatus ?? this.depositStatus,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    notes: notes,
    refundAmount: refundAmount ?? this.refundAmount,
    history: history ?? this.history,
    isDemo: isDemo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'folio': folio,
    'serviceId': serviceId,
    'serviceTitle': serviceTitle,
    'artisanId': artisanId,
    'touristId': touristId,
    'touristName': touristName,
    'touristPhone': touristPhone,
    'date': date.toIso8601String(),
    'timeSlot': timeSlot,
    'people': people,
    'status': status.name,
    'totalAmount': totalAmount,
    'depositAmount': depositAmount,
    'depositStatus': depositStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'notes': notes,
    'refundAmount': refundAmount,
    'history': history.map((event) => event.toJson()).toList(),
    'isDemo': isDemo,
  };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String,
    folio: json['folio'] as String,
    serviceId: json['serviceId'] as String,
    serviceTitle: json['serviceTitle'] as String,
    artisanId: json['artisanId'] as String,
    touristId: json['touristId'] as String,
    touristName: json['touristName'] as String,
    touristPhone: json['touristPhone'] as String,
    date: DateTime.parse(json['date'] as String),
    timeSlot: json['timeSlot'] as String,
    people: json['people'] as int,
    status: BookingStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => BookingStatus.requested,
    ),
    totalAmount: json['totalAmount'] as int,
    depositAmount: json['depositAmount'] as int,
    depositStatus: DepositStatus.values.firstWhere(
      (status) => status.name == json['depositStatus'],
      orElse: () => DepositStatus.none,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    notes: json['notes'] as String?,
    refundAmount: json['refundAmount'] as int? ?? 0,
    history: (json['history'] as List<dynamic>? ?? const [])
        .map((item) => BookingEvent.fromJson(item as Map<String, dynamic>))
        .toList(),
    isDemo: json['isDemo'] as bool? ?? true,
  );
}

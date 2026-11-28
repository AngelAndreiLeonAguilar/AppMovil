/// Notificaciones internas (campana del artesano y del turista).
library;

enum AppNotificationType {
  newBooking('Nueva solicitud'),
  requestSent('Solicitud enviada'),
  accepted('Reserva confirmada'),
  rejected('Reserva rechazada'),
  cancelled('Reserva cancelada'),
  completed('Visita completada'),
  noShow('No-show registrado'),
  reminder('Recordatorio de visita'),
  newOrder('Nueva compra'),
  orderUpdate('Pedido de compra'),
  subscription('Mensualidad');

  const AppNotificationType(this.label);

  final String label;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.bookingId,
    this.isRead = false,
    this.delivered = true,
  });

  final String id;

  /// Usuario que debe verla.
  final String userId;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;

  /// `true` cuando ya se mostró en la barra de notificaciones del teléfono.
  final bool delivered;

  AppNotification copyWith({bool? isRead, bool? delivered}) =>
      AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    bookingId: bookingId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    delivered: delivered ?? this.delivered,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'title': title,
    'body': body,
    'bookingId': bookingId,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'delivered': delivered,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['userId'] as String,
    type: AppNotificationType.values.firstWhere(
      (type) => type.name == json['type'],
      orElse: () => AppNotificationType.newBooking,
    ),
    title: json['title'] as String,
    body: json['body'] as String,
    bookingId: json['bookingId'] as String?,
    isRead: json['isRead'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    delivered: json['delivered'] as bool? ?? true,
  );
}

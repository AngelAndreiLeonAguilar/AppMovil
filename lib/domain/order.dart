/// Pedidos de compra de artesanías con recogida presencial en el taller.
///
/// Bel-Aaktun no hace envíos: el turista compra en la app y recoge su pedido
/// en el taller en la fecha y hora que acuerda el artesano.
library;

import 'user.dart';

enum OrderStatus {
  requested('Pendiente de aceptación', 'El taller revisará tu pedido.'),
  accepted('Aceptado', 'El taller aceptó tu pedido.'),
  preparing('En preparación', 'El taller está preparando tu pedido.'),
  ready('Listo para recoger', 'Tu pedido te espera en el taller.'),
  delivered('Entregado', 'El pedido ya fue entregado.'),
  rejected('Rechazado', 'El taller no pudo aceptar el pedido.'),
  cancelledByBuyer('Cancelado', 'El comprador canceló el pedido.'),
  cancelledByArtisan('Cancelado por el taller', 'El taller canceló el pedido.');

  const OrderStatus(this.label, this.description);

  final String label;
  final String description;

  /// Pedido en curso (todavía no termina).
  bool get isOpen =>
      this == requested ||
      this == accepted ||
      this == preparing ||
      this == ready;

  bool get isClosed => !isOpen;

  /// El taller ya se comprometió a venderlo.
  bool get isAcceptedByArtisan =>
      this == accepted || this == preparing || this == ready;

  /// Lee estados guardados por versiones anteriores de la app.
  static OrderStatus fromName(String? name) => switch (name) {
    'confirmed' => OrderStatus.accepted,
    _ => OrderStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => OrderStatus.requested,
    ),
  };
}

/// Una pieza dentro de un pedido. El precio se congela al comprar.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.productImage,
  });

  final String productId;
  final String productName;
  final String? productImage;

  /// Precio por pieza en MXN al momento de la compra.
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productImage': productImage,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['productId'] as String,
    productName: json['productName'] as String? ?? '',
    productImage: json['productImage'] as String?,
    unitPrice: json['unitPrice'] as int? ?? 0,
    quantity: json['quantity'] as int? ?? 1,
  );
}

class OrderEvent {
  const OrderEvent({
    required this.status,
    required this.at,
    this.byRole,
    this.note,
  });

  final OrderStatus status;
  final DateTime at;
  final String? byRole;
  final String? note;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'at': at.toIso8601String(),
    'byRole': byRole,
    'note': note,
  };

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
    status: OrderStatus.fromName(json['status'] as String?),
    at: DateTime.parse(json['at'] as String),
    byRole: json['byRole'] as String?,
    note: json['note'] as String?,
  );
}

/// Pedido de un turista a UN taller. Si el carrito tiene piezas de varios
/// talleres, se genera un pedido por taller.
///
/// La app no cobra: el pago se hace en el taller al recoger, hasta que exista
/// una pasarela de pagos integrada.
class Order {
  const Order({
    required this.id,
    required this.folio,
    required this.artisanId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.pickupAt,
    this.pickupNote,
    this.stockReserved = false,
    this.history = const [],
  });

  final String id;
  final String folio;
  final String artisanId;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final List<OrderItem> items;

  /// Indicaciones del comprador (talla, color, dedicatoria…).
  final String? notes;
  final OrderStatus status;

  /// Fecha y hora estimadas para recoger, definidas por el taller.
  final DateTime? pickupAt;

  /// Indicaciones del taller para la recogida.
  final String? pickupNote;

  /// `true` cuando ya se descontaron piezas del inventario del taller.
  final bool stockReserved;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderEvent> history;

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);

  int get pieceCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// "Sombrero Brisa" o "Sombrero Brisa y 2 más".
  String get title {
    if (items.isEmpty) return 'Pedido';
    if (items.length == 1) return items.first.productName;
    return '${items.first.productName} y ${items.length - 1} más';
  }

  String? get coverImage => items.isEmpty ? null : items.first.productImage;

  Order copyWith({
    OrderStatus? status,
    bool? stockReserved,
    DateTime? updatedAt,
    DateTime? pickupAt,
    String? pickupNote,
    List<OrderEvent>? history,
  }) => Order(
    id: id,
    folio: folio,
    artisanId: artisanId,
    buyerId: buyerId,
    buyerName: buyerName,
    buyerPhone: buyerPhone,
    items: items,
    notes: notes,
    status: status ?? this.status,
    pickupAt: pickupAt ?? this.pickupAt,
    pickupNote: pickupNote ?? this.pickupNote,
    stockReserved: stockReserved ?? this.stockReserved,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'folio': folio,
    'artisanId': artisanId,
    'buyerId': buyerId,
    'buyerName': buyerName,
    'buyerPhone': buyerPhone,
    'items': items.map((item) => item.toJson()).toList(),
    'notes': notes,
    'status': status.name,
    'pickupAt': pickupAt?.toIso8601String(),
    'pickupNote': pickupNote,
    'stockReserved': stockReserved,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'history': history.map((event) => event.toJson()).toList(),
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final items = rawItems != null
        ? [
            for (final item in rawItems)
              OrderItem.fromJson(item as Map<String, dynamic>),
          ]
        : [
            // Pedidos de una sola pieza guardados por versiones anteriores.
            OrderItem(
              productId: json['productId'] as String? ?? '',
              productName: json['productName'] as String? ?? '',
              productImage: json['productImage'] as String?,
              unitPrice: json['unitPrice'] as int? ?? 0,
              quantity: json['quantity'] as int? ?? 1,
            ),
          ];
    return Order(
      id: json['id'] as String,
      folio: json['folio'] as String,
      artisanId: json['artisanId'] as String,
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String? ?? '',
      buyerPhone: json['buyerPhone'] as String? ?? '',
      items: items,
      notes: json['notes'] as String?,
      status: OrderStatus.fromName(json['status'] as String?),
      pickupAt: DateTime.tryParse(json['pickupAt'] as String? ?? ''),
      pickupNote: json['pickupNote'] as String?,
      stockReserved: json['stockReserved'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      history: [
        for (final item in (json['history'] as List<dynamic>? ?? const []))
          OrderEvent.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

/// Línea del carrito (se guarda solo en el teléfono del turista).
class CartLine {
  const CartLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    productId: json['productId'] as String,
    quantity: json['quantity'] as int? ?? 1,
  );
}

/// Acción disponible sobre un pedido.
class OrderAction {
  const OrderAction(this.next, this.label, {this.destructive = false});

  final OrderStatus next;
  final String label;
  final bool destructive;
}

class OrderRuleError implements Exception {
  OrderRuleError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Quién puede mover un pedido y hacia dónde.
abstract final class OrderRules {
  static const _artisan = <OrderStatus, List<OrderStatus>>{
    OrderStatus.requested: [OrderStatus.accepted, OrderStatus.rejected],
    OrderStatus.accepted: [
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.cancelledByArtisan,
    ],
    OrderStatus.preparing: [OrderStatus.ready, OrderStatus.cancelledByArtisan],
    OrderStatus.ready: [OrderStatus.delivered, OrderStatus.cancelledByArtisan],
  };

  static const _buyer = <OrderStatus, List<OrderStatus>>{
    OrderStatus.requested: [OrderStatus.cancelledByBuyer],
    OrderStatus.accepted: [OrderStatus.cancelledByBuyer],
  };

  static bool canMove(OrderStatus from, OrderStatus to, UserRole role) {
    final table = switch (role) {
      UserRole.artisan => _artisan,
      UserRole.tourist => _buyer,
      UserRole.admin => const <OrderStatus, List<OrderStatus>>{},
    };
    return table[from]?.contains(to) ?? false;
  }

  /// El taller puede fijar o cambiar la fecha de recogida mientras el pedido
  /// esté aceptado y no se haya entregado.
  static bool canSchedulePickup(Order order, UserRole role) =>
      role == UserRole.artisan && order.status.isAcceptedByArtisan;

  static List<OrderAction> actionsFor(Order order, UserRole role) {
    final actions = <OrderAction>[];
    for (final next in OrderStatus.values) {
      if (!canMove(order.status, next, role)) continue;
      actions.add(switch (next) {
        OrderStatus.accepted => const OrderAction(
          OrderStatus.accepted,
          'Aceptar pedido',
        ),
        OrderStatus.preparing => const OrderAction(
          OrderStatus.preparing,
          'Marcar en preparación',
        ),
        OrderStatus.ready => const OrderAction(
          OrderStatus.ready,
          'Marcar listo para recoger',
        ),
        OrderStatus.delivered => const OrderAction(
          OrderStatus.delivered,
          'Marcar entregado',
        ),
        OrderStatus.rejected => const OrderAction(
          OrderStatus.rejected,
          'Rechazar',
          destructive: true,
        ),
        OrderStatus.cancelledByArtisan => const OrderAction(
          OrderStatus.cancelledByArtisan,
          'Cancelar pedido',
          destructive: true,
        ),
        OrderStatus.cancelledByBuyer => const OrderAction(
          OrderStatus.cancelledByBuyer,
          'Cancelar mi pedido',
          destructive: true,
        ),
        OrderStatus.requested => const OrderAction(OrderStatus.requested, ''),
      });
    }
    return actions;
  }

  /// Aplica la transición o lanza [OrderRuleError].
  static Order apply(
    Order order,
    OrderStatus next, {
    required UserRole by,
    String? note,
    DateTime? pickupAt,
    DateTime? now,
  }) {
    if (!canMove(order.status, next, by)) {
      throw OrderRuleError(
        'No se puede pasar de "${order.status.label}" a "${next.label}".',
      );
    }
    final at = now ?? DateTime.now();
    final pickup = pickupAt ?? order.pickupAt;
    if (pickupAt != null && !pickupAt.isAfter(at)) {
      throw OrderRuleError('La fecha de recogida debe ser futura.');
    }
    if (next == OrderStatus.ready && pickup == null) {
      throw OrderRuleError(
        'Indica cuándo puede pasar el cliente por su pedido.',
      );
    }
    return order.copyWith(
      status: next,
      pickupAt: pickupAt,
      updatedAt: at,
      history: [
        ...order.history,
        OrderEvent(status: next, at: at, byRole: by.name, note: note),
      ],
    );
  }

  /// Fija o cambia la fecha de recogida sin cambiar el estado.
  static Order schedulePickup(
    Order order,
    DateTime pickupAt, {
    required UserRole by,
    String? note,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    if (!canSchedulePickup(order, by)) {
      throw OrderRuleError(
        'Solo el taller puede programar la recogida de un pedido aceptado.',
      );
    }
    if (!pickupAt.isAfter(at)) {
      throw OrderRuleError('La fecha de recogida debe ser futura.');
    }
    return order.copyWith(
      pickupAt: pickupAt,
      pickupNote: note,
      updatedAt: at,
      history: [
        ...order.history,
        OrderEvent(
          status: order.status,
          at: at,
          byRole: by.name,
          note: 'Recogida programada',
        ),
      ],
    );
  }
}

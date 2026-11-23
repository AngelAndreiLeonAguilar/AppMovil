/// Comisiones de Bel-Aaktun y registro financiero.
///
/// Reglas:
/// - Cada operación (una venta o una reservación) tiene **un solo** asiento,
///   identificado por `source:sourceId`. Los cambios lo actualizan; nunca se
///   duplica.
/// - Una comisión solo es **ingreso devengado** cuando la operación se
///   completa (pedido entregado / visita realizada). Mientras está aceptada es
///   **por confirmar**; si se rechaza o cancela queda **anulada** y no cuenta.
/// - La tasa se congela en el asiento cuando la operación se acepta: cambiar
///   la tasa después no altera operaciones anteriores.
/// - La app no procesa pagos: el cliente paga en el taller. Por eso la
///   comisión devengada queda **por liquidar** (el taller la debe a la
///   plataforma) hasta que se registre su pago con una referencia real.
library;

/// Tipo de operación que genera comisión.
enum LedgerSource {
  sale('Venta de piezas'),
  visit('Visita o experiencia');

  const LedgerSource(this.label);

  final String label;
}

/// Situación contable de la comisión.
enum LedgerStatus {
  /// Operación aceptada, todavía no completada. No es ingreso.
  pending('Por confirmar'),

  /// Operación completada. Ingreso devengado de la plataforma.
  earned('Devengada'),

  /// Operación rechazada o cancelada. No cuenta.
  voided('Anulada');

  const LedgerStatus(this.label);

  final String label;
}

/// Tasas de comisión vigentes, en puntos base (1000 = 10 %).
class CommissionSettings {
  const CommissionSettings({
    this.saleRateBps = defaultSaleRateBps,
    this.visitRateBps = defaultVisitRateBps,
    this.updatedAt,
    this.updatedBy,
  });

  static const defaultSaleRateBps = 1000;
  static const defaultVisitRateBps = 1500;

  /// Máximo permitido para evitar errores de captura (50 %).
  static const maxRateBps = 5000;

  final int saleRateBps;
  final int visitRateBps;
  final DateTime? updatedAt;
  final String? updatedBy;

  int rateFor(LedgerSource source) => switch (source) {
    LedgerSource.sale => saleRateBps,
    LedgerSource.visit => visitRateBps,
  };

  Map<String, dynamic> toJson() => {
    'saleRateBps': saleRateBps,
    'visitRateBps': visitRateBps,
    'updatedAt': updatedAt?.toIso8601String(),
    'updatedBy': updatedBy,
  };

  factory CommissionSettings.fromJson(Map<String, dynamic> json) =>
      CommissionSettings(
        saleRateBps: json['saleRateBps'] as int? ?? defaultSaleRateBps,
        visitRateBps: json['visitRateBps'] as int? ?? defaultVisitRateBps,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        updatedBy: json['updatedBy'] as String?,
      );
}

/// "10 %" o "12.5 %".
String formatRate(int bps) {
  final whole = bps ~/ 100;
  final rest = bps % 100;
  if (rest == 0) return '$whole %';
  final decimals = rest % 10 == 0
      ? '${rest ~/ 10}'
      : rest.toString().padLeft(2, '0');
  return '$whole.$decimals %';
}

/// Desglose de un importe bruto.
class CommissionSplit {
  const CommissionSplit({
    required this.gross,
    required this.rateBps,
    required this.commission,
  });

  /// Calcula la comisión redondeando al peso más cercano.
  factory CommissionSplit.of(int gross, int rateBps) => CommissionSplit(
    gross: gross,
    rateBps: rateBps,
    commission: (gross * rateBps / 10000).round(),
  );

  final int gross;
  final int rateBps;
  final int commission;

  /// Lo que corresponde al artesano o prestador.
  int get net => gross - commission;
}

class LedgerEvent {
  const LedgerEvent({required this.status, required this.at, this.note});

  final LedgerStatus status;
  final DateTime at;
  final String? note;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'at': at.toIso8601String(),
    'note': note,
  };

  factory LedgerEvent.fromJson(Map<String, dynamic> json) => LedgerEvent(
    status: LedgerStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => LedgerStatus.pending,
    ),
    at: DateTime.parse(json['at'] as String),
    note: json['note'] as String?,
  );
}

/// Asiento del registro financiero: una operación con su desglose.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.folio,
    required this.artisanId,
    required this.customerName,
    required this.description,
    required this.gross,
    required this.rateBps,
    required this.commission,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.earnedAt,
    this.settledAt,
    this.settlementRef,
    this.history = const [],
  });

  /// Clave única de la operación: `sale:od-123` o `visit:bk-456`.
  static String keyFor(LedgerSource source, String sourceId) =>
      '${source.name}:$sourceId';

  final String id;
  final LedgerSource source;
  final String sourceId;
  final String folio;
  final String artisanId;
  final String customerName;
  final String description;

  /// Importe total de la operación en MXN.
  final int gross;

  /// Tasa aplicada (congelada al aceptar la operación).
  final int rateBps;

  /// Comisión de Bel-Aaktun en MXN.
  final int commission;
  final LedgerStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Cuándo se completó la operación (comisión devengada).
  final DateTime? earnedAt;

  /// Cuándo se registró el pago de la comisión a la plataforma.
  final DateTime? settledAt;

  /// Referencia del pago (recibo, transferencia…). Sin ella no hay liquidación.
  final String? settlementRef;
  final List<LedgerEvent> history;

  String get key => keyFor(source, sourceId);

  /// Lo que corresponde al artesano o prestador.
  int get artisanNet => gross - commission;

  bool get isSettled => settledAt != null;

  /// Comisión devengada que el taller todavía no ha pagado a la plataforma.
  bool get isPendingSettlement => status == LedgerStatus.earned && !isSettled;

  LedgerEntry copyWith({
    int? gross,
    int? commission,
    String? description,
    LedgerStatus? status,
    DateTime? updatedAt,
    DateTime? earnedAt,
    DateTime? settledAt,
    String? settlementRef,
    List<LedgerEvent>? history,
  }) => LedgerEntry(
    id: id,
    source: source,
    sourceId: sourceId,
    folio: folio,
    artisanId: artisanId,
    customerName: customerName,
    description: description ?? this.description,
    gross: gross ?? this.gross,
    rateBps: rateBps,
    commission: commission ?? this.commission,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    earnedAt: earnedAt ?? this.earnedAt,
    settledAt: settledAt ?? this.settledAt,
    settlementRef: settlementRef ?? this.settlementRef,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.name,
    'sourceId': sourceId,
    'folio': folio,
    'artisanId': artisanId,
    'customerName': customerName,
    'description': description,
    'gross': gross,
    'rateBps': rateBps,
    'commission': commission,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'earnedAt': earnedAt?.toIso8601String(),
    'settledAt': settledAt?.toIso8601String(),
    'settlementRef': settlementRef,
    'history': history.map((event) => event.toJson()).toList(),
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as String,
    source: LedgerSource.values.firstWhere(
      (source) => source.name == json['source'],
      orElse: () => LedgerSource.sale,
    ),
    sourceId: json['sourceId'] as String,
    folio: json['folio'] as String? ?? '',
    artisanId: json['artisanId'] as String,
    customerName: json['customerName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    gross: json['gross'] as int? ?? 0,
    rateBps: json['rateBps'] as int? ?? 0,
    commission: json['commission'] as int? ?? 0,
    status: LedgerStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => LedgerStatus.pending,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    earnedAt: DateTime.tryParse(json['earnedAt'] as String? ?? ''),
    settledAt: DateTime.tryParse(json['settledAt'] as String? ?? ''),
    settlementRef: json['settlementRef'] as String?,
    history: [
      for (final item in (json['history'] as List<dynamic>? ?? const []))
        LedgerEvent.fromJson(item as Map<String, dynamic>),
    ],
  );
}

/// Totales de un conjunto de asientos.
class FinanceSummary {
  const FinanceSummary({
    required this.grossEarned,
    required this.commissionEarned,
    required this.artisanNetEarned,
    required this.commissionPending,
    required this.grossPending,
    required this.commissionToSettle,
    required this.commissionSettled,
    required this.completedCount,
    required this.pendingCount,
    required this.voidedCount,
  });

  factory FinanceSummary.of(Iterable<LedgerEntry> entries) {
    var grossEarned = 0;
    var commissionEarned = 0;
    var commissionPending = 0;
    var grossPending = 0;
    var commissionToSettle = 0;
    var commissionSettled = 0;
    var completed = 0;
    var pending = 0;
    var voided = 0;
    for (final entry in entries) {
      switch (entry.status) {
        case LedgerStatus.earned:
          completed++;
          grossEarned += entry.gross;
          commissionEarned += entry.commission;
          if (entry.isSettled) {
            commissionSettled += entry.commission;
          } else {
            commissionToSettle += entry.commission;
          }
        case LedgerStatus.pending:
          pending++;
          commissionPending += entry.commission;
          grossPending += entry.gross;
        case LedgerStatus.voided:
          voided++;
      }
    }
    return FinanceSummary(
      grossEarned: grossEarned,
      commissionEarned: commissionEarned,
      artisanNetEarned: grossEarned - commissionEarned,
      commissionPending: commissionPending,
      grossPending: grossPending,
      commissionToSettle: commissionToSettle,
      commissionSettled: commissionSettled,
      completedCount: completed,
      pendingCount: pending,
      voidedCount: voided,
    );
  }

  /// Ventas o visitas completadas (bruto).
  final int grossEarned;

  /// Ingreso real de Bel-Aaktun: comisiones de operaciones completadas.
  final int commissionEarned;

  /// Lo que corresponde a los artesanos de operaciones completadas.
  final int artisanNetEarned;

  /// Comisión de operaciones aceptadas aún no completadas (no es ingreso).
  final int commissionPending;

  /// Importe de operaciones aceptadas aún no completadas.
  final int grossPending;

  /// Lo que recibirían los artesanos de lo aceptado sin completar.
  int get artisanNetPending => grossPending - commissionPending;

  /// Comisión devengada que los talleres aún no pagan a la plataforma.
  final int commissionToSettle;

  /// Comisión devengada con pago registrado.
  final int commissionSettled;
  final int completedCount;
  final int pendingCount;
  final int voidedCount;
}

/// Barra de una semana: etiqueta y monto.
class FinanceWeek {
  const FinanceWeek({required this.label, required this.amount});

  final String label;
  final int amount;
}

/// Ingreso neto del taller por semana (operaciones completadas), de la más
/// antigua a la actual.
List<FinanceWeek> netByWeek(
  Iterable<LedgerEntry> entries, {
  int weeks = 4,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  final result = <FinanceWeek>[];
  for (var i = weeks - 1; i >= 0; i--) {
    final start = monday.subtract(Duration(days: 7 * i));
    final end = start.add(const Duration(days: 7));
    var amount = 0;
    for (final entry in entries) {
      final at = entry.earnedAt;
      if (entry.status != LedgerStatus.earned || at == null) continue;
      if (!at.isBefore(start) && at.isBefore(end)) amount += entry.artisanNet;
    }
    result.add(
      FinanceWeek(
        label: i == 0 ? 'Esta' : '${start.day}/${start.month}',
        amount: amount,
      ),
    );
  }
  return result;
}

/// Rendimiento de un mes (operaciones completadas en ese mes).
class MonthPerformance {
  const MonthPerformance({
    required this.month,
    required this.gross,
    required this.commission,
    required this.sales,
    required this.visits,
  });

  /// Primer día del mes.
  final DateTime month;
  final int gross;
  final int commission;
  final int sales;
  final int visits;

  int get operations => sales + visits;
}

/// Últimos [months] meses, del más reciente al más antiguo.
List<MonthPerformance> monthlyPerformance(
  Iterable<LedgerEntry> entries, {
  int months = 6,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final result = <MonthPerformance>[];
  for (var i = 0; i < months; i++) {
    final start = DateTime(today.year, today.month - i);
    final end = DateTime(today.year, today.month - i + 1);
    var gross = 0;
    var commission = 0;
    var sales = 0;
    var visits = 0;
    for (final entry in entries) {
      final at = entry.earnedAt;
      if (entry.status != LedgerStatus.earned || at == null) continue;
      if (at.isBefore(start) || !at.isBefore(end)) continue;
      gross += entry.gross;
      commission += entry.commission;
      if (entry.source == LedgerSource.sale) {
        sales++;
      } else {
        visits++;
      }
    }
    result.add(
      MonthPerformance(
        month: start,
        gross: gross,
        commission: commission,
        sales: sales,
        visits: visits,
      ),
    );
  }
  return result;
}

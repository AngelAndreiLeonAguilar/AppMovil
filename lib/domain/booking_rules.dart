/// Reglas de negocio de las reservaciones.
///
/// Funciones puras, sin Flutter: se prueban solas y se reutilizan en la app.
library;

import 'booking.dart';
import 'user.dart';

/// Error de negocio al intentar un cambio de estado no permitido.
class BookingRuleError implements Exception {
  BookingRuleError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resultado del cálculo de un anticipo al cancelar.
class DepositOutcome {
  const DepositOutcome(this.status, this.refund);

  final DepositStatus status;

  /// Monto a devolver al turista en MXN.
  final int refund;
}

abstract final class BookingRules {
  /// Horas de anticipación para reembolso completo.
  static const int fullRefundHours = 48;

  /// Horas de anticipación para reembolso del 50 %.
  static const int halfRefundHours = 24;

  /// Fecha y hora exactas de la visita.
  static DateTime visitAt(Booking booking) {
    final parts = booking.timeSlot.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      hour,
      minute,
    );
  }

  /// Transiciones válidas según el rol que las ejecuta.
  static bool canChange(BookingStatus from, BookingStatus to, UserRole by) {
    switch (from) {
      case BookingStatus.requested:
        return switch (to) {
          BookingStatus.accepted ||
          BookingStatus.rejected ||
          BookingStatus.cancelledByArtisan => by == UserRole.artisan,
          BookingStatus.cancelledByTourist => by == UserRole.tourist,
          _ => false,
        };
      case BookingStatus.accepted:
        return switch (to) {
          BookingStatus.completed ||
          BookingStatus.noShow ||
          BookingStatus.cancelledByArtisan => by == UserRole.artisan,
          BookingStatus.cancelledByTourist => by == UserRole.tourist,
          _ => false,
        };
      case BookingStatus.rejected:
      case BookingStatus.completed:
      case BookingStatus.cancelledByTourist:
      case BookingStatus.cancelledByArtisan:
      case BookingStatus.noShow:
        return false;
    }
  }

  /// Acciones disponibles para un rol sobre una reservación.
  static List<BookingStatus> actionsFor(Booking booking, UserRole by) => [
    for (final status in BookingStatus.values)
      if (canChange(booking.status, status, by)) status,
  ];

  /// Aplica una transición y devuelve la reservación actualizada.
  static Booking apply(
    Booking booking,
    BookingStatus next, {
    required UserRole by,
    DateTime? now,
    String? note,
  }) {
    if (!canChange(booking.status, next, by)) {
      throw BookingRuleError(
        'No se puede pasar de "${booking.status.label}" a "${next.label}".',
      );
    }

    final at = now ?? DateTime.now();
    final deposit = _depositOutcome(booking, next, by, at);

    return booking.copyWith(
      status: next,
      depositStatus: deposit.status,
      refundAmount: deposit.refund,
      updatedAt: at,
      history: [
        ...booking.history,
        BookingEvent(status: next, at: at, byRole: by.name, note: note),
      ],
    );
  }

  static DepositOutcome _depositOutcome(
    Booking booking,
    BookingStatus next,
    UserRole by,
    DateTime now,
  ) {
    if (!booking.hasDeposit) return const DepositOutcome(DepositStatus.none, 0);

    if (next == BookingStatus.completed) {
      return DepositOutcome(booking.depositStatus, 0);
    }

    if (next == BookingStatus.noShow) {
      return DepositOutcome(DepositStatus.forfeited, 0);
    }

    if (next == BookingStatus.rejected || next == BookingStatus.cancelledByArtisan) {
      return DepositOutcome(DepositStatus.refunded, booking.depositAmount);
    }

    if (next == BookingStatus.cancelledByTourist) {
      final hours = visitAt(booking).difference(now).inHours;
      if (hours >= fullRefundHours) {
        return DepositOutcome(DepositStatus.refunded, booking.depositAmount);
      }
      if (hours >= halfRefundHours) {
        final half = booking.depositAmount ~/ 2;
        return DepositOutcome(DepositStatus.partiallyRefunded, half);
      }
      return const DepositOutcome(DepositStatus.forfeited, 0);
    }

    return DepositOutcome(booking.depositStatus, 0);
  }

  /// Anticipo que corresponde a una reserva nueva.
  static int depositFor({required int total, required int percent}) {
    if (total <= 0 || percent <= 0) return 0;
    return (total * percent / 100).round();
  }

  /// Mensaje para el turista según la política de cancelación.
  static String cancellationPolicyFor(Booking booking, {DateTime? now}) {
    final hours = visitAt(booking).difference(now ?? DateTime.now()).inHours;
    if (hours >= fullRefundHours) {
      return 'Cancelas con más de 48 h: devolución completa del anticipo.';
    }
    if (hours >= halfRefundHours) {
      return 'Cancelas entre 24 y 48 h: devolución del 50 % del anticipo.';
    }
    return 'Cancelas con menos de 24 h: el anticipo no es reembolsable.';
  }
}

/// Cálculos de dinero y actividad a partir de las reservaciones.
///
/// La regla central: una reservación agendada **no** es un ingreso. Solo las
/// visitas completadas (y los anticipos retenidos por no-show) cuentan como
/// dinero cobrado.
library;

import 'booking.dart';

class MoneySummary {
  const MoneySummary({
    required this.collected,
    required this.receivable,
    required this.pending,
    required this.cancelled,
  });

  /// Anticipos cobrados de visitas completadas + anticipos retenidos.
  final int collected;

  /// Saldo por cobrar de visitas confirmadas (aún no realizadas).
  final int receivable;

  /// Total de solicitudes pendientes de aceptar (dinero hipotético).
  final int pending;

  /// Total de reservaciones rechazadas o canceladas (informativo).
  final int cancelled;

  int get total => collected + receivable;
}

MoneySummary summariseMoney(Iterable<Booking> bookings) {
  var collected = 0;
  var receivable = 0;
  var pending = 0;
  var cancelled = 0;

  for (final booking in bookings) {
    switch (booking.status) {
      case BookingStatus.completed:
        collected += booking.depositAmount;
        break;
      case BookingStatus.noShow:
        if (booking.depositStatus == DepositStatus.forfeited) {
          collected += booking.depositAmount;
        }
        break;
      case BookingStatus.accepted:
        receivable += booking.balance;
        break;
      case BookingStatus.requested:
        pending += booking.totalAmount;
        break;
      case BookingStatus.rejected:
      case BookingStatus.cancelledByTourist:
      case BookingStatus.cancelledByArtisan:
        cancelled += booking.totalAmount;
        break;
    }
  }

  return MoneySummary(
    collected: collected,
    receivable: receivable,
    pending: pending,
    cancelled: cancelled,
  );
}

/// Contadores para el dashboard del artesano.
class BookingCounters {
  const BookingCounters({
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.upcoming,
  });

  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;

  /// Visitas confirmadas en los próximos 7 días.
  final int upcoming;
}

BookingCounters countBookings(
  Iterable<Booking> bookings, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final horizon = today.add(const Duration(days: 7));

  var pending = 0;
  var confirmed = 0;
  var completed = 0;
  var cancelled = 0;
  var noShow = 0;
  var upcoming = 0;

  for (final booking in bookings) {
    switch (booking.status) {
      case BookingStatus.requested:
        pending++;
        break;
      case BookingStatus.accepted:
        confirmed++;
        if (!booking.date.isBefore(today) && !booking.date.isAfter(horizon)) {
          upcoming++;
        }
        break;
      case BookingStatus.completed:
        completed++;
        break;
      case BookingStatus.noShow:
        noShow++;
        break;
      case BookingStatus.rejected:
      case BookingStatus.cancelledByTourist:
      case BookingStatus.cancelledByArtisan:
        cancelled++;
        break;
    }
  }

  return BookingCounters(
    pending: pending,
    confirmed: confirmed,
    completed: completed,
    cancelled: cancelled,
    noShow: noShow,
    upcoming: upcoming,
  );
}

/// Punto de una gráfica de barras.
class WeekBar {
  const WeekBar({required this.label, required this.amount});

  final String label;
  final int amount;
}

/// Anticipos cobrados por semana en las últimas [weeks] semanas.
List<WeekBar> collectedByWeek(
  Iterable<Booking> bookings, {
  int weeks = 4,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final startOfWeek = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));

  final buckets = List<int>.filled(weeks, 0);

  for (final booking in bookings) {
    if (booking.status != BookingStatus.completed) continue;
    final visit = DateTime(booking.date.year, booking.date.month, booking.date.day);
    final diff = startOfWeek.difference(visit).inDays;
    if (diff < 0) continue;
    final index = weeks - 1 - (diff ~/ 7);
    if (index < 0 || index >= weeks) continue;
    buckets[index] += booking.depositAmount;
  }

  return [
    for (var i = 0; i < weeks; i++)
      WeekBar(label: 'S${i + 1}', amount: buckets[i]),
  ];
}

/// Servicios ordenados por número de visitas completadas.
class ServiceRank {
  const ServiceRank({
    required this.serviceTitle,
    required this.visits,
    required this.people,
  });

  final String serviceTitle;
  final int visits;
  final int people;
}

List<ServiceRank> topServices(Iterable<Booking> bookings, {int limit = 3}) {
  final visits = <String, int>{};
  final people = <String, int>{};

  for (final booking in bookings) {
    if (booking.status != BookingStatus.completed) continue;
    visits.update(
      booking.serviceTitle,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    people.update(
      booking.serviceTitle,
      (value) => value + booking.people,
      ifAbsent: () => booking.people,
    );
  }

  final ranking = [
    for (final entry in visits.entries)
      ServiceRank(
        serviceTitle: entry.key,
        visits: entry.value,
        people: people[entry.key] ?? 0,
      ),
  ]..sort((a, b) => b.visits.compareTo(a.visits));

  return ranking.take(limit).toList();
}

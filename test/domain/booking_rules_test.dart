import 'package:bel_aaktun/domain/booking.dart';
import 'package:bel_aaktun/domain/booking_rules.dart';
import 'package:bel_aaktun/domain/money.dart';
import 'package:bel_aaktun/domain/user.dart';
import 'package:flutter_test/flutter_test.dart';

Booking booking({
  BookingStatus status = BookingStatus.requested,
  int total = 700,
  int deposit = 210,
  int dayOffset = 5,
  String timeSlot = '10:00',
  DepositStatus depositStatus = DepositStatus.simulatedPaid,
}) {
  final now = DateTime(2026, 3, 10, 8);
  return Booking(
    id: 'bk-test',
    folio: 'BA-2000',
    serviceId: 'exp-01',
    serviceTitle: 'Recorrido por las cuevas',
    artisanId: 'art-01',
    touristId: 'u-turista',
    touristName: 'Turista demo',
    touristPhone: '+52 981 000 0000',
    date: DateTime(2026, 3, 10 + dayOffset),
    timeSlot: timeSlot,
    people: 2,
    status: status,
    totalAmount: total,
    depositAmount: deposit,
    depositStatus: deposit > 0 ? depositStatus : DepositStatus.none,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('transiciones', () {
    test('el artesano acepta una solicitud', () {
      expect(
        BookingRules.canChange(
          BookingStatus.requested,
          BookingStatus.accepted,
          UserRole.artisan,
        ),
        isTrue,
      );
    });

    test('el turista no puede aceptar su propia reserva', () {
      expect(
        BookingRules.canChange(
          BookingStatus.requested,
          BookingStatus.accepted,
          UserRole.tourist,
        ),
        isFalse,
      );
    });

    test('una reserva completada ya no cambia', () {
      expect(
        BookingRules.canChange(
          BookingStatus.completed,
          BookingStatus.accepted,
          UserRole.artisan,
        ),
        isFalse,
      );
    });

    test('aplicar una transición deja historial', () {
      final updated = BookingRules.apply(
        booking(),
        BookingStatus.accepted,
        by: UserRole.artisan,
        now: DateTime(2026, 3, 10, 9),
      );

      expect(updated.status, BookingStatus.accepted);
      expect(updated.history, hasLength(1));
      expect(updated.history.single.byRole, 'artisan');
    });

    test('una transición inválida lanza error de negocio', () {
      expect(
        () => BookingRules.apply(
          booking(status: BookingStatus.completed),
          BookingStatus.accepted,
          by: UserRole.artisan,
        ),
        throwsA(isA<BookingRuleError>()),
      );
    });
  });

  group('anticipos y reembolsos', () {
    final now = DateTime(2026, 3, 10, 8);

    test('rechazo del taller devuelve todo el anticipo', () {
      final updated = BookingRules.apply(
        booking(),
        BookingStatus.rejected,
        by: UserRole.artisan,
        now: now,
      );

      expect(updated.depositStatus, DepositStatus.refunded);
      expect(updated.refundAmount, 210);
    });

    test('cancelación con más de 48 h devuelve todo', () {
      final updated = BookingRules.apply(
        booking(dayOffset: 5),
        BookingStatus.cancelledByTourist,
        by: UserRole.tourist,
        now: now,
      );

      expect(updated.depositStatus, DepositStatus.refunded);
      expect(updated.refundAmount, 210);
    });

    test('cancelación entre 24 y 48 h devuelve la mitad', () {
      final visit = DateTime(2026, 3, 12, 10);
      final updated = BookingRules.apply(
        booking(dayOffset: 2),
        BookingStatus.cancelledByTourist,
        by: UserRole.tourist,
        now: visit.subtract(const Duration(hours: 30)),
      );

      expect(updated.depositStatus, DepositStatus.partiallyRefunded);
      expect(updated.refundAmount, 105);
    });

    test('cancelación con menos de 24 h no devuelve nada', () {
      final visit = DateTime(2026, 3, 12, 10);
      final updated = BookingRules.apply(
        booking(dayOffset: 2),
        BookingStatus.cancelledByTourist,
        by: UserRole.tourist,
        now: visit.subtract(const Duration(hours: 5)),
      );

      expect(updated.depositStatus, DepositStatus.forfeited);
      expect(updated.refundAmount, 0);
    });

    test('no-show retiene el anticipo', () {
      final updated = BookingRules.apply(
        booking(status: BookingStatus.accepted),
        BookingStatus.noShow,
        by: UserRole.artisan,
        now: now,
      );

      expect(updated.depositStatus, DepositStatus.forfeited);
    });

    test('el anticipo se calcula por porcentaje', () {
      expect(BookingRules.depositFor(total: 700, percent: 30), 210);
      expect(BookingRules.depositFor(total: 700, percent: 0), 0);
      expect(BookingRules.depositFor(total: 0, percent: 30), 0);
    });
  });

  group('dinero', () {
    test('solo las visitas completadas y los no-show cuentan como cobrado', () {
      final summary = summariseMoney([
        booking(status: BookingStatus.completed, deposit: 210),
        booking(
          status: BookingStatus.noShow,
          deposit: 210,
          depositStatus: DepositStatus.forfeited,
        ),
        booking(status: BookingStatus.accepted, total: 700, deposit: 210),
        booking(status: BookingStatus.requested, total: 700, deposit: 210),
      ]);

      expect(summary.collected, 420);
      expect(summary.receivable, 490);
      expect(summary.pending, 700);
    });

    test('los contadores separan pendientes, confirmadas y completadas', () {
      final counters = countBookings(
        [
          booking(status: BookingStatus.requested),
          booking(status: BookingStatus.requested),
          booking(status: BookingStatus.accepted, dayOffset: 2),
          booking(status: BookingStatus.completed, dayOffset: -2),
          booking(status: BookingStatus.noShow, dayOffset: -1),
        ],
        now: DateTime(2026, 3, 10, 8),
      );

      expect(counters.pending, 2);
      expect(counters.confirmed, 1);
      expect(counters.upcoming, 1);
      expect(counters.completed, 1);
      expect(counters.noShow, 1);
    });

    test('el ranking de servicios solo mira visitas completadas', () {
      final ranking = topServices([
        booking(status: BookingStatus.completed),
        booking(status: BookingStatus.completed),
        booking(status: BookingStatus.accepted),
      ]);

      expect(ranking, hasLength(1));
      expect(ranking.first.visits, 2);
      expect(ranking.first.people, 4);
    });
  });
}

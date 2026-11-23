import '../domain/app_notification.dart';
import '../domain/booking.dart';
import 'demo_content.dart';

/// Reservaciones de ejemplo para revisar el panel del artesano.
///
/// Son datos de demostración: fechas relativas a hoy, folios ficticios y
/// depósitos marcados como `simulatedPaid`. No representan transacciones.
List<Booking> seedBookings({DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  final caveTour = DemoContent.experiences[0];
  final weaving = DemoContent.experiences[1];
  final meeting = DemoContent.experiences[2];

  Booking build({
    required String id,
    required String folio,
    required String serviceId,
    required String serviceTitle,
    required String artisanId,
    required String touristId,
    required String touristName,
    required String touristPhone,
    required int dayOffset,
    required String timeSlot,
    required int people,
    required int total,
    required int deposit,
    required BookingStatus status,
    required DepositStatus depositStatus,
    required int createdHoursAgo,
    int refund = 0,
    String? notes,
  }) {
    final visitDay = day.add(Duration(days: dayOffset));
    final createdAt = today.subtract(Duration(hours: createdHoursAgo));
    final updatedAt = createdAt.add(const Duration(minutes: 20));

    return Booking(
      id: id,
      folio: folio,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      artisanId: artisanId,
      touristId: touristId,
      touristName: touristName,
      touristPhone: touristPhone,
      date: visitDay,
      timeSlot: timeSlot,
      people: people,
      status: status,
      totalAmount: total,
      depositAmount: deposit,
      depositStatus: depositStatus,
      refundAmount: refund,
      createdAt: createdAt,
      updatedAt: updatedAt,
      notes: notes,
      history: [
        BookingEvent(
          status: status,
          at: updatedAt,
          byRole: status == BookingStatus.requested ? 'tourist' : 'artisan',
        ),
      ],
    );
  }

  int totalFor(int price, int people) => price * people;

  return [
    build(
      id: 'bk-seed-01',
      folio: 'BA-1001',
      serviceId: caveTour.id,
      serviceTitle: caveTour.title,
      artisanId: caveTour.artisanId,
      touristId: 'u-turista',
      touristName: 'Turista demo',
      touristPhone: '+52 981 000 0001',
      dayOffset: 3,
      timeSlot: '10:30',
      people: 2,
      total: totalFor(caveTour.pricePerPerson, 2),
      deposit: caveTour.depositFor(2),
      status: BookingStatus.requested,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 2,
      notes: 'Llegamos en camión desde Campeche.',
    ),
    build(
      id: 'bk-seed-02',
      folio: 'BA-1002',
      serviceId: weaving.id,
      serviceTitle: weaving.title,
      artisanId: weaving.artisanId,
      touristId: 'u-visitante-2',
      touristName: 'María Pech (demo)',
      touristPhone: '+52 981 000 0002',
      dayOffset: 5,
      timeSlot: '12:00',
      people: 4,
      total: totalFor(weaving.pricePerPerson, 4),
      deposit: weaving.depositFor(4),
      status: BookingStatus.requested,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 5,
    ),
    build(
      id: 'bk-seed-03',
      folio: 'BA-1003',
      serviceId: caveTour.id,
      serviceTitle: caveTour.title,
      artisanId: caveTour.artisanId,
      touristId: 'u-turista',
      touristName: 'Turista demo',
      touristPhone: '+52 981 000 0001',
      dayOffset: 1,
      timeSlot: '09:00',
      people: 2,
      total: totalFor(caveTour.pricePerPerson, 2),
      deposit: caveTour.depositFor(2),
      status: BookingStatus.accepted,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 30,
    ),
    build(
      id: 'bk-seed-04',
      folio: 'BA-1004',
      serviceId: meeting.id,
      serviceTitle: meeting.title,
      artisanId: meeting.artisanId,
      touristId: 'u-visitante-3',
      touristName: 'Familia Canul (demo)',
      touristPhone: '+52 981 000 0003',
      dayOffset: 2,
      timeSlot: '16:00',
      people: 3,
      total: totalFor(meeting.pricePerPerson, 3),
      deposit: meeting.depositFor(3),
      status: BookingStatus.accepted,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 48,
    ),
    build(
      id: 'bk-seed-05',
      folio: 'BA-1005',
      serviceId: caveTour.id,
      serviceTitle: caveTour.title,
      artisanId: caveTour.artisanId,
      touristId: 'u-turista',
      touristName: 'Turista demo',
      touristPhone: '+52 981 000 0001',
      dayOffset: -3,
      timeSlot: '10:30',
      people: 2,
      total: totalFor(caveTour.pricePerPerson, 2),
      deposit: caveTour.depositFor(2),
      status: BookingStatus.completed,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 120,
    ),
    build(
      id: 'bk-seed-06',
      folio: 'BA-1006',
      serviceId: weaving.id,
      serviceTitle: weaving.title,
      artisanId: weaving.artisanId,
      touristId: 'u-visitante-4',
      touristName: 'Grupo escolar (demo)',
      touristPhone: '+52 981 000 0004',
      dayOffset: -10,
      timeSlot: '09:00',
      people: 6,
      total: totalFor(weaving.pricePerPerson, 6),
      deposit: weaving.depositFor(6),
      status: BookingStatus.completed,
      depositStatus: DepositStatus.simulatedPaid,
      createdHoursAgo: 240,
    ),
    build(
      id: 'bk-seed-07',
      folio: 'BA-1007',
      serviceId: meeting.id,
      serviceTitle: meeting.title,
      artisanId: meeting.artisanId,
      touristId: 'u-visitante-5',
      touristName: 'Jorge Uc (demo)',
      touristPhone: '+52 981 000 0005',
      dayOffset: -6,
      timeSlot: '17:30',
      people: 2,
      total: totalFor(meeting.pricePerPerson, 2),
      deposit: meeting.depositFor(2),
      status: BookingStatus.cancelledByTourist,
      depositStatus: DepositStatus.refunded,
      refund: meeting.depositFor(2),
      createdHoursAgo: 200,
    ),
    build(
      id: 'bk-seed-08',
      folio: 'BA-1008',
      serviceId: caveTour.id,
      serviceTitle: caveTour.title,
      artisanId: caveTour.artisanId,
      touristId: 'u-visitante-6',
      touristName: 'Sofía Balam (demo)',
      touristPhone: '+52 981 000 0006',
      dayOffset: -1,
      timeSlot: '17:30',
      people: 2,
      total: totalFor(caveTour.pricePerPerson, 2),
      deposit: caveTour.depositFor(2),
      status: BookingStatus.noShow,
      depositStatus: DepositStatus.forfeited,
      createdHoursAgo: 90,
    ),
  ];
}

/// Notificaciones iniciales para la cuenta demo del taller.
List<AppNotification> seedNotifications({DateTime? now}) {
  final today = now ?? DateTime.now();

  return [
    AppNotification(
      id: 'nt-seed-01',
      userId: 'u-art-01',
      type: AppNotificationType.newBooking,
      title: 'Nueva solicitud de Turista demo',
      body: 'Recorrido por las cuevas · 2 personas. Revisa y confirma.',
      bookingId: 'bk-seed-01',
      createdAt: today.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'nt-seed-02',
      userId: 'u-art-01',
      type: AppNotificationType.completed,
      title: 'Visita completada',
      body: 'Recorrido por las cuevas · 2 personas. Anticipo cobrado.',
      bookingId: 'bk-seed-05',
      createdAt: today.subtract(const Duration(hours: 20)),
      isRead: true,
    ),
    AppNotification(
      id: 'nt-seed-03',
      userId: 'u-turista',
      type: AppNotificationType.accepted,
      title: 'Tu visita fue confirmada',
      body: 'Recorrido por las cuevas · mañana a las 09:00.',
      bookingId: 'bk-seed-03',
      createdAt: today.subtract(const Duration(hours: 20)),
    ),
  ];
}

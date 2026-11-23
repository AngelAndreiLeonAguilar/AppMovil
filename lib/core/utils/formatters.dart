/// Utilidades de formato en español (México).
library;

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _weekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

/// `4200` → `$4,200`. Un precio nulo significa "a consultar".
String formatPrice(int? value) {
  if (value == null) return 'Precio a consultar';

  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '\$${buffer.toString()} MXN';
}

String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

String weekdayLong(DateTime date) => _weekdays[date.weekday - 1];

String monthLong(DateTime date) => _months[date.month - 1];

/// `14 de marzo de 2026`.
String formatLongDate(DateTime date) =>
    '${date.day} de ${monthLong(date)} de ${date.year}';

/// `14 mar`.
String formatShortDate(DateTime date) {
  final month = monthLong(date);
  return '${date.day} ${month.substring(0, 3)}';
}

/// `1 h 30 min`.
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return '$hours h';
  return '$hours h $rest min';
}

/// Tiempo relativo en español: `hace 2 h`, `ayer`, `hace 3 días`.
String formatRelative(DateTime moment, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(moment);

  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  if (diff.inDays < 7) return 'hace ${diff.inDays} días';
  if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7} sem';
  return formatShortDate(moment);
}

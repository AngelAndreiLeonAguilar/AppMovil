import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';

/// Enlaces para contactar a un taller o a un turista.
abstract final class ContactLinks {
  /// Solo dígitos; agrega la lada de México si el número viene a 10 dígitos.
  static String digits(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 10) return '52$clean';
    return clean;
  }

  static Uri whatsapp(String phone, {String? message}) => Uri.https(
    'wa.me',
    '/${digits(phone)}',
    {if (message != null && message.isNotEmpty) 'text': message},
  );

  static Uri call(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));

  static Uri email(String address, {String? subject}) => Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
  );

  static Future<void> open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir esa app en este teléfono.'),
        ),
      );
    }
  }
}

const weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// "Lun a Sáb · 09:00–18:00" o `null` si el taller no definió horario.
String? scheduleLabel(Artisan artisan) {
  if (!artisan.hasSchedule) return null;
  final days = [...artisan.openDays]..sort();
  String dayText;
  final consecutive =
      days.length > 2 &&
      days.last - days.first == days.length - 1;
  if (days.length == 7) {
    dayText = 'Todos los días';
  } else if (consecutive) {
    dayText = '${weekdayShort[days.first - 1]} a ${weekdayShort[days.last - 1]}';
  } else {
    dayText = days.map((day) => weekdayShort[day - 1]).join(', ');
  }
  return '$dayText · ${artisan.openTime}–${artisan.closeTime}';
}

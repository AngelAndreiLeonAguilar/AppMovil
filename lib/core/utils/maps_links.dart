import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enlaces profundos a mapas.
///
/// Abren Google Maps si está instalado (o su versión web si no) para ver un
/// punto o trazar la ruta desde donde esté el visitante.
abstract final class MapsLinks {
  /// Ficha de un lugar: `https://www.google.com/maps/search/?api=1&query=lat,lng`
  static Uri point(double latitude, double longitude, {String? label}) {
    final query = label == null || label.trim().isEmpty
        ? '$latitude,$longitude'
        : '$latitude,$longitude ($label)';
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  /// Ruta paso a paso hasta el punto.
  static Uri directions(
    double latitude,
    double longitude, {
    String travelMode = 'driving',
    String? label,
  }) {
    final destination = label == null || label.trim().isEmpty
        ? '$latitude,$longitude'
        : '$latitude,$longitude ($label)';
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': travelMode,
    });
  }

  /// Abre el enlace fuera de la app. Devuelve `false` si el sistema no puede.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Abre el enlace o avisa al usuario si el dispositivo no tiene con qué.
  static Future<void> openOrWarn(BuildContext context, Uri uri) async {
    final opened = await open(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la app de mapas en este dispositivo.'),
        ),
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_store.dart';

/// Almacén compartido con el servidor de pruebas de la red local.
///
/// Los datos que deben verse en todos los teléfonos (cuentas, talleres,
/// catálogo, reservas, compras y avisos) viven en el servidor
/// (`tools/servidor_pruebas/servidor.py`). La sesión, el tema y los permisos
/// se quedan en cada teléfono.
///
/// Las lecturas son síncronas desde una copia en memoria; [refresh] la pone
/// al día. Si una escritura falla por la red, queda pendiente y se reintenta
/// antes de la siguiente lectura para no perder cambios.
class SyncStore implements LocalStore {
  SyncStore(this._local, String baseUrl, {http.Client? client})
    : baseUrl = normalizeSyncUrl(baseUrl) ?? baseUrl,
      _client = client ?? http.Client();

  /// Claves que se comparten entre teléfonos.
  static const sharedKeys = {
    'local.auth.v1',
    'bookings.v1',
    'notifications.v1',
    'products.v1',
    'services.v1',
    'artisans.v1',
    'orders.v1',
    'avatars.v1',
    'ledger.v1',
    'finance.settings.v1',
  };

  static const _timeout = Duration(seconds: 8);

  final LocalStore _local;
  final String baseUrl;
  final http.Client _client;

  final Map<String, String> _cache = {};
  final Map<String, String?> _pending = {};
  int _version = -1;
  bool _online = false;

  /// `true` si la última comunicación con el servidor funcionó.
  bool get isOnline => _online;

  /// Versión de los datos del servidor que tiene este teléfono.
  int get version => _version;

  bool _shared(String key) => sharedKeys.contains(key);

  @override
  String? read(String key) => _shared(key) ? _cache[key] : _local.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (!_shared(key)) return _local.write(key, value);
    _cache[key] = value;
    _pending[key] = value;
    await _flush();
  }

  @override
  Future<void> delete(String key) async {
    if (!_shared(key)) return _local.delete(key);
    _cache.remove(key);
    _pending[key] = null;
    await _flush();
  }

  /// Envía las escrituras pendientes. Devuelve `true` si no quedó ninguna.
  Future<bool> _flush() async {
    for (final key in [..._pending.keys]) {
      final value = _pending[key];
      final uri = Uri.parse('$baseUrl/state/$key');
      try {
        final response = value == null
            ? await _client.delete(uri).timeout(_timeout)
            : await _client
                  .put(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: value,
                  )
                  .timeout(_timeout);
        if (response.statusCode >= 400) {
          debugPrint('Servidor rechazó $key: ${response.body}');
          _pending.remove(key);
          continue;
        }
        // La versión solo se actualiza al leer (refresh): si otro teléfono
        // escribió al mismo tiempo, la siguiente lectura traerá su cambio.
        // Solo se quita si nadie la volvió a cambiar mientras se enviaba.
        if (identical(_pending[key], value) || _pending[key] == value) {
          _pending.remove(key);
        }
        _online = true;
      } catch (error) {
        _online = false;
        return false;
      }
    }
    return true;
  }

  @override
  Future<bool> refresh() async {
    // Primero lo pendiente: así no se pisa con datos viejos del servidor.
    if (!await _flush()) return false;
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/state'))
          .timeout(_timeout);
      if (response.statusCode >= 400) {
        _online = false;
        return false;
      }
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      _online = true;
      final version = decoded['version'] as int? ?? 0;
      if (version == _version && _pending.isEmpty) return false;
      final values = Map<String, dynamic>.from(decoded['values'] as Map);
      _cache
        ..clear()
        ..addAll({
          for (final entry in values.entries)
            if (_shared(entry.key) && entry.value is String)
              entry.key: entry.value as String,
        });
      _version = version;
      return true;
    } catch (_) {
      _online = false;
      return false;
    }
  }

  /// Sube una foto y devuelve su URL completa.
  Future<String> uploadPhoto(Uint8List bytes, String extension) async {
    final type = switch (extension.toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final response = await _client
        .post(
          Uri.parse('$baseUrl/fotos'),
          headers: {'Content-Type': type},
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) {
      throw Exception('El servidor no aceptó la foto.');
    }
    final path =
        (jsonDecode(response.body) as Map<String, dynamic>)['path'] as String;
    return '$baseUrl$path';
  }

  /// Comprueba que en esa dirección esté el servidor de pruebas.
  /// Devuelve `null` si todo bien o el mensaje de error.
  static Future<String?> check(String url, {http.Client? client}) async {
    final normalized = normalizeSyncUrl(url);
    if (normalized == null) {
      return 'Escribe la dirección que muestra el servidor, ej. 192.168.1.50';
    }
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('$normalized/health'))
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['app'] != 'bel-aaktun') {
        return 'En esa dirección responde otro programa.';
      }
      return null;
    } catch (_) {
      return 'No hay respuesta en $normalized. Revisa que el servidor esté '
          'abierto en la computadora y que el teléfono esté en el mismo WiFi.';
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// "192.168.1.50" → "http://192.168.1.50:8787". `null` si no es válida.
String? normalizeSyncUrl(String input) {
  var text = input.trim().replaceAll(RegExp(r'/+$'), '');
  if (text.isEmpty) return null;
  if (!text.startsWith('http://') && !text.startsWith('https://')) {
    text = 'http://$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : 8787;
  return '${uri.scheme}://${uri.host}:$port';
}

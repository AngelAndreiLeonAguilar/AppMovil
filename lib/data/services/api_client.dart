import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error de la API con el mensaje que devuelve el servidor.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Cliente HTTP mínimo de la API de Bel-Aaktun.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
  }) => _send('GET', path, token: token);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) => _send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      final request = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const {}),
        ),
        _ => throw ArgumentError('Método no soportado: $method'),
      };
      // Sin límite, un servidor inalcanzable deja la pantalla congelada.
      response = await request.timeout(const Duration(seconds: 12));
    } catch (error) {
      if (error is ArgumentError) rethrow;
      throw ApiException(
        0,
        'No se pudo conectar con $baseUrl. Revisa que el servidor esté '
        'encendido, que la URL sea correcta y tu conexión.',
      );
    }

    Map<String, dynamic> decoded = const {};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final parsed = jsonDecode(utf8.decode(response.bodyBytes));
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } catch (_) {
        // Respuesta no JSON: se reporta como error genérico más abajo.
      }
    }

    if (response.statusCode >= 400) {
      final message = decoded['error']?.toString() ?? 'Error del servidor.';
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  void close() => _client.close();
}

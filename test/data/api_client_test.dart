import 'package:bel_aaktun/data/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('el error de conexión incluye la URL del servidor', () async {
    final client = ApiClient(
      baseUrl: 'http://192.168.1.50:5001/api/v1',
      client: MockClient((request) async => throw Exception('sin red')),
    );

    try {
      await client.get('/health');
      fail('Debió lanzar ApiException');
    } on ApiException catch (error) {
      expect(error.statusCode, 0);
      expect(error.message, contains('192.168.1.50'));
      expect(error.message, contains('servidor'));
    }
  });

  test('usa el mensaje de error que devuelve la API', () async {
    final client = ApiClient(
      baseUrl: 'http://x/api/v1',
      client: MockClient(
        (request) async => http.Response(
          '{"error":"Ese correo ya está registrado."}',
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    try {
      await client.post('/auth/register');
      fail('Debió lanzar ApiException');
    } on ApiException catch (error) {
      expect(error.statusCode, 409);
      expect(error.message, 'Ese correo ya está registrado.');
    }
  });
}

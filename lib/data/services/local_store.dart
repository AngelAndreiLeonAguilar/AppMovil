import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento clave-valor de la app.
///
/// En el dispositivo usa `shared_preferences`; en pruebas (o si el plugin no
/// está disponible) cae a memoria, para que la app nunca truene por eso.
abstract class LocalStore {
  static Future<LocalStore> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _PrefsStore(prefs);
    } catch (_) {
      return MemoryStore();
    }
  }

  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Trae cambios hechos desde otros teléfonos (solo el almacén
  /// sincronizado). Devuelve `true` si algo cambió.
  Future<bool> refresh() async => false;
}

class _PrefsStore implements LocalStore {
  _PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> delete(String key) => _prefs.remove(key);

  @override
  Future<bool> refresh() async => false;
}

/// Implementación en memoria (pruebas y respaldo).
class MemoryStore implements LocalStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<bool> refresh() async => false;
}

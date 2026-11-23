import 'dart:convert';

import '../../domain/booking.dart';
import '../services/local_store.dart';

/// Acceso a las reservaciones.
///
/// La interfaz permite sustituir la implementación local por una remota
/// (Supabase/Firebase) sin tocar la interfaz de usuario.
abstract interface class BookingRepository {
  Future<List<Booking>> load();

  Future<void> save(List<Booking> bookings);
}

/// Implementación local sobre [LocalStore] (JSON en `shared_preferences`).
class LocalBookingRepository implements BookingRepository {
  LocalBookingRepository(this._store);

  static const _key = 'bookings.v1';

  final LocalStore _store;

  @override
  Future<List<Booking>> load() async {
    final raw = _store.read(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Booking.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Datos corruptos o de una versión anterior: se empieza limpio.
      return [];
    }
  }

  @override
  Future<void> save(List<Booking> bookings) async {
    await _store.write(
      _key,
      jsonEncode(bookings.map((booking) => booking.toJson()).toList()),
    );
  }
}

/// Repositorio en memoria para pruebas.
class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository([List<Booking> seed = const []])
    : _bookings = [...seed];

  List<Booking> _bookings;

  @override
  Future<List<Booking>> load() async => [..._bookings];

  @override
  Future<void> save(List<Booking> bookings) async =>
      _bookings = [...bookings];
}

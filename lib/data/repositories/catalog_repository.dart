import 'dart:convert';

import '../../data/demo_content.dart';
import '../models.dart';
import '../services/local_store.dart';

/// Catálogo editable del taller (piezas y experiencias).
class CatalogData {
  const CatalogData({required this.products, required this.services});

  final List<Product> products;
  final List<Experience> services;
}

/// Acceso al catálogo. Interfaz lista para sustituirse por un backend.
abstract interface class CatalogRepository {
  Future<CatalogData> load();

  Future<void> save(CatalogData data);
}

/// Implementación local: JSON en `shared_preferences`.
///
/// Si no hay datos guardados, siembra el catálogo de demostración.
class LocalCatalogRepository implements CatalogRepository {
  LocalCatalogRepository(this._store);

  static const _productsKey = 'products.v1';
  static const _servicesKey = 'services.v1';

  final LocalStore _store;

  @override
  Future<CatalogData> load() async {
    final products = _decode<Product>(
      _store.read(_productsKey),
      Product.fromJson,
      fallback: DemoContent.products,
    );
    final services = _decode<Experience>(
      _store.read(_servicesKey),
      Experience.fromJson,
      fallback: DemoContent.experiences,
    );
    return CatalogData(products: products, services: services);
  }

  @override
  Future<void> save(CatalogData data) async {
    await _store.write(
      _productsKey,
      jsonEncode(data.products.map((product) => product.toJson()).toList()),
    );
    await _store.write(
      _servicesKey,
      jsonEncode(data.services.map((service) => service.toJson()).toList()),
    );
  }

  List<T> _decode<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson, {
    required List<T> fallback,
  }) {
    if (raw == null || raw.isEmpty) return [...fallback];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      // Una lista vacía es válida: significa que el taller borró todo.
      return decoded
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [...fallback];
    }
  }
}

/// Catálogo en memoria para pruebas.
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository([CatalogData? seed])
    : _data =
          seed ??
          CatalogData(
            products: [...DemoContent.products],
            services: [...DemoContent.experiences],
          );

  CatalogData _data;

  @override
  Future<CatalogData> load() async => _data;

  @override
  Future<void> save(CatalogData data) async => _data = data;
}

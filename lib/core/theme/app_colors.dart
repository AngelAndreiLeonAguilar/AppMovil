import 'package:flutter/material.dart';

/// Paleta oficial de Bel-Aaktun.
///
/// Inspirada en las cuevas artesanales de Bécal, Campeche y en el tejido del
/// sombrero de Jipi Japa: marrones de tierra, terracota de barro cocido, crema
/// de palma seca y dorado del sombreado.
abstract final class AppColors {
  /// Marrón oscuro — fondo del modo oscuro y tinta principal del modo claro.
  static const marronOscuro = Color(0xFF21140E);

  /// Marrón profundo — superficies elevadas en modo oscuro.
  static const marronProfundo = Color(0xFF302018);

  /// Terracota — acciones principales, botones y acentos.
  static const terracota = Color(0xFFD65F38);

  /// Crema — superficie dominante de contenido en modo claro.
  static const crema = Color(0xFFF5F0E5);

  /// Dorado palma — detalles, sellos y datos culturales.
  static const doradoPalma = Color(0xFFC99A32);

  /// Blanco cálido — tarjetas y campos en modo claro.
  static const blancoCalido = Color(0xFFFFF9F0);

  // ---------------------------------------------------------------------------
  // Derivados: se usan solo para estados, bordes y capas de profundidad.
  // ---------------------------------------------------------------------------

  static const terracotaClaro = Color(0xFFE87F58);
  static const terracotaOscuro = Color(0xFFB1482A);

  static const arena = Color(0xFFE6DCC8);
  static const arenaHonda = Color(0xFFD8CCB4);

  static const marronMedio = Color(0xFF4A3327);
  static const marronSuave = Color(0xFF6B5240);

  static const doradoClaro = Color(0xFFE0B75C);

  static const error = Color(0xFFB3261E);
  static const errorOscuro = Color(0xFFF2B8B5);
}

/// Escala de espaciado y radios de Bel-Aaktun.
///
/// Se usa una retícula de 4 pt para que todo el ritmo visual sea consistente
/// en pantallas pequeñas.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3l = 32;
  static const double x4l = 40;
  static const double x5l = 56;

  /// Margen horizontal estándar de las pantallas.
  static const double page = 20;

  /// Altura mínima de un objetivo táctil.
  static const double touch = 48;

  /// Ancho máximo de contenido en tablet / escritorio.
  static const double maxContent = 720;
}

/// Radios: ligeramente redondeados, nunca completamente cuadrados.
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

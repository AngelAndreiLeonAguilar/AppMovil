import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Jerarquía tipográfica de Bel-Aaktun.
///
/// - [serif] (Playfair Display) para títulos y encabezados.
/// - [cultural] (Cormorant Garamond) para frases culturales y subtítulos.
/// - [sans] (Lato) para textos, descripciones y botones.
abstract final class AppTypography {
  static const serif = 'PlayfairDisplay';
  static const cultural = 'CormorantGaramond';
  static const sans = 'Lato';

  static TextTheme textTheme(Color text, Color muted) {
    return TextTheme(
      // Playfair Display
      displayLarge: TextStyle(
        fontFamily: serif,
        fontSize: 46,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: text,
      ),
      displayMedium: TextStyle(
        fontFamily: serif,
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: text,
      ),
      displaySmall: TextStyle(
        fontFamily: serif,
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: text,
      ),
      headlineLarge: TextStyle(
        fontFamily: serif,
        fontSize: 28,
        height: 1.16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: text,
      ),
      headlineMedium: TextStyle(
        fontFamily: serif,
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      headlineSmall: TextStyle(
        fontFamily: serif,
        fontSize: 21,
        height: 1.24,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleLarge: TextStyle(
        fontFamily: serif,
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: text,
      ),
      titleMedium: TextStyle(
        fontFamily: sans,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: text,
      ),
      titleSmall: TextStyle(
        fontFamily: sans,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: text,
      ),

      // Lato
      bodyLarge: TextStyle(
        fontFamily: sans,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: text,
      ),
      bodyMedium: TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: text,
      ),
      bodySmall: TextStyle(
        fontFamily: sans,
        fontSize: 12.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: muted,
      ),

      // Etiquetas y botones
      labelLarge: TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: text,
      ),
      labelMedium: TextStyle(
        fontFamily: sans,
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: text,
      ),
      labelSmall: TextStyle(
        fontFamily: sans,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: muted,
      ),
    );
  }

  /// Frase cultural o subtítulo en Cormorant Garamond.
  static TextStyle quote({
    double size = 20,
    Color? color,
    FontStyle style = FontStyle.italic,
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
  }) {
    return TextStyle(
      fontFamily: cultural,
      fontSize: size,
      height: height,
      fontWeight: weight,
      fontStyle: style,
      color: color ?? AppColors.marronOscuro,
    );
  }

  /// Antetítulo en mayúsculas con tracking amplio (Lato).
  static TextStyle eyebrow({Color? color, double size = 11}) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.4,
      color: color ?? AppColors.terracota,
    );
  }
}

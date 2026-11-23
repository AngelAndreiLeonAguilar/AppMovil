import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tokens de color que no encajan en [ColorScheme] pero que la interfaz
/// necesita en ambos modos (claro y oscuro).
@immutable
class BelPalette extends ThemeExtension<BelPalette> {
  const BelPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.artworkBase,
    required this.artworkGlow,
    required this.artworkVeil,
    required this.navSurface,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color border;
  final Color artworkBase;
  final Color artworkGlow;
  final Color artworkVeil;
  final Color navSurface;
  final Color shadow;

  static const light = BelPalette(
    background: AppColors.crema,
    surface: AppColors.blancoCalido,
    surfaceMuted: Color(0xFFEFE7D7),
    text: AppColors.marronOscuro,
    textMuted: Color(0xFF6F5A48),
    textFaint: Color(0xFF8E7A66),
    border: Color(0xFFE2D6C2),
    artworkBase: AppColors.marronProfundo,
    artworkGlow: Color(0xFF8C4A2C),
    artworkVeil: AppColors.crema,
    navSurface: AppColors.blancoCalido,
    shadow: Color(0x1F21140E),
  );

  static const dark = BelPalette(
    background: AppColors.marronOscuro,
    surface: AppColors.marronProfundo,
    surfaceMuted: Color(0xFF3B2820),
    text: AppColors.crema,
    textMuted: Color(0xFFC9B7A6),
    textFaint: Color(0xFF9C8775),
    border: Color(0xFF4B362A),
    artworkBase: Color(0xFF2A1A13),
    artworkGlow: Color(0xFFA54C2C),
    artworkVeil: AppColors.marronOscuro,
    navSurface: Color(0xFF2A1A14),
    shadow: Color(0x66000000),
  );

  @override
  BelPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? border,
    Color? artworkBase,
    Color? artworkGlow,
    Color? artworkVeil,
    Color? navSurface,
    Color? shadow,
  }) {
    return BelPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      border: border ?? this.border,
      artworkBase: artworkBase ?? this.artworkBase,
      artworkGlow: artworkGlow ?? this.artworkGlow,
      artworkVeil: artworkVeil ?? this.artworkVeil,
      navSurface: navSurface ?? this.navSurface,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  BelPalette lerp(covariant BelPalette? other, double t) {
    if (other == null) return this;
    return BelPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      artworkBase: Color.lerp(artworkBase, other.artworkBase, t)!,
      artworkGlow: Color.lerp(artworkGlow, other.artworkGlow, t)!,
      artworkVeil: Color.lerp(artworkVeil, other.artworkVeil, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

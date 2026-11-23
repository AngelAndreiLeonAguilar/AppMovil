import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'bel_palette.dart';

/// Tema de Bel-Aaktun.
///
/// Un mismo sistema de diseño en dos modos:
/// - **Claro**: la crema domina las superficies de contenido.
/// - **Oscuro**: marrones profundos con acentos terracota y dorado.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? BelPalette.dark : BelPalette.light;
    final scheme = _scheme(brightness, palette);
    final textTheme = AppTypography.textTheme(palette.text, palette.textMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      fontFamily: AppTypography.sans,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: palette.text,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.text, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? palette.surfaceMuted : AppColors.marronOscuro,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.blancoCalido,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: palette.border,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        isDense: true,
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textFaint),
        helperStyle: textTheme.bodySmall?.copyWith(color: palette.textFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        disabledColor: palette.surfaceMuted,
        checkmarkColor: scheme.onPrimary,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: palette.text),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: scheme.primary, size: 18),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : palette.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : palette.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : palette.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : palette.surfaceMuted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : palette.textMuted,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: palette.surfaceMuted,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: AppColors.marronOscuro,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.blancoCalido,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textMuted,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.textMuted,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.marronOscuro,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.blancoCalido,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  static ColorScheme _scheme(Brightness brightness, BelPalette palette) {
    final isDark = brightness == Brightness.dark;

    return ColorScheme(
      brightness: brightness,
      primary: AppColors.terracota,
      onPrimary: AppColors.blancoCalido,
      primaryContainer: isDark
          ? const Color(0xFF4C2A1D)
          : const Color(0xFFF6DCD2),
      onPrimaryContainer: isDark
          ? const Color(0xFFF8D7C9)
          : const Color(0xFF5A2416),
      secondary: isDark ? AppColors.doradoClaro : AppColors.doradoPalma,
      onSecondary: AppColors.marronOscuro,
      secondaryContainer: isDark
          ? const Color(0xFF443216)
          : const Color(0xFFF2E4C4),
      onSecondaryContainer: isDark
          ? const Color(0xFFF4E2BB)
          : const Color(0xFF4A370F),
      tertiary: isDark ? AppColors.terracotaClaro : AppColors.terracotaOscuro,
      onTertiary: AppColors.blancoCalido,
      error: isDark ? AppColors.errorOscuro : AppColors.error,
      onError: isDark ? AppColors.marronOscuro : AppColors.blancoCalido,
      surface: palette.surface,
      onSurface: palette.text,
      surfaceContainerLowest: isDark ? AppColors.marronOscuro : palette.surface,
      surfaceContainerLow: isDark ? const Color(0xFF35231A) : palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceMuted,
      surfaceContainerHighest: palette.surfaceMuted,
      onSurfaceVariant: palette.textMuted,
      outline: palette.border,
      outlineVariant: palette.border,
      shadow: palette.shadow,
      scrim: AppColors.marronOscuro,
      inverseSurface: isDark ? AppColors.crema : AppColors.marronOscuro,
      onInverseSurface: isDark ? AppColors.marronOscuro : AppColors.crema,
      inversePrimary: AppColors.terracotaClaro,
    );
  }
}

/// Atajos de tema para no repetir `Theme.of(context)` en cada widget.
extension BelThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  BelPalette get palette =>
      Theme.of(this).extension<BelPalette>() ?? BelPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Antetítulo en mayúsculas con tracking amplio.
  TextStyle get eyebrowStyle => AppTypography.eyebrow(color: colors.primary);

  /// Frase cultural o subtítulo en Cormorant Garamond.
  TextStyle quoteStyle({double size = 20, Color? color}) =>
      AppTypography.quote(size: size, color: color ?? palette.textMuted);
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'bel_button.dart';

/// Botón de cambio de modo claro/oscuro.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return BelIconButton(
      icon: context.isDark
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined,
      tooltip: context.isDark
          ? 'Cambiar a modo claro'
          : 'Cambiar a modo oscuro',
      filled: filled,
      onPressed: () => ThemeScope.of(context).toggle(),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Etiqueta pequeña para datos culturales (técnica, cueva, material).
class BelPill extends StatelessWidget {
  const BelPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.palette.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs + 2,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tint),
            const SizedBox(width: Insets.xs + 2),
          ],
          Text(
            label,
            style: context.texts.labelMedium?.copyWith(
              color: tint,
              letterSpacing: 0.2,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtro seleccionable del catálogo.
class BelFilterChip extends StatelessWidget {
  const BelFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.lg,
      vertical: Insets.sm + 2,
    ),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final palette = context.palette;

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : palette.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? scheme.primary : palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                color: selected ? scheme.onPrimary : palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

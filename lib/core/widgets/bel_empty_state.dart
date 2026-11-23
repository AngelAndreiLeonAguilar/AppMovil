import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'bel_button.dart';
import 'bel_surface.dart';

/// Estado vacío común de Bel-Aaktun: ícono, título, explicación y, si aplica,
/// una acción para salir del vacío.
class BelEmptyState extends StatelessWidget {
  const BelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.framed = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Con marco (tarjeta) dentro de listas; sin marco a pantalla completa.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: context.colors.primary),
        ),
        const SizedBox(height: Insets.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.texts.titleMedium,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.texts.bodySmall?.copyWith(
            color: palette.textMuted,
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: Insets.lg),
          BelButton(
            label: actionLabel!,
            icon: actionIcon,
            variant: BelButtonVariant.outline,
            compact: true,
            expand: false,
            onPressed: onAction,
          ),
        ],
      ],
    );

    if (!framed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.x3l),
          child: content,
        ),
      );
    }
    return BelSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.xxl,
      ),
      child: SizedBox(width: double.infinity, child: content),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum BelButtonVariant {
  /// Terracota: acción principal.
  primary,

  /// Contorno: acción secundaria sobre superficies crema.
  outline,

  /// Crema sobre fotografía oscura.
  light,

  /// Texto terracota sin relleno.
  ghost,
}

/// Botón de Bel-Aaktun con respuesta táctil sutil.
class BelButton extends StatefulWidget {
  const BelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = BelButtonVariant.primary,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BelButtonVariant variant;
  final bool expand;
  final bool compact;

  @override
  State<BelButton> createState() => _BelButtonState();
}

class _BelButtonState extends State<BelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final palette = context.palette;
    final enabled = widget.onPressed != null;

    late final Color background;
    late final Color foreground;
    late final Border? border;

    switch (widget.variant) {
      case BelButtonVariant.primary:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        border = null;
      case BelButtonVariant.outline:
        background = Colors.transparent;
        foreground = palette.text;
        border = Border.all(color: palette.border, width: 1.3);
      case BelButtonVariant.light:
        background = AppColors.blancoCalido;
        foreground = AppColors.marronOscuro;
        border = null;
      case BelButtonVariant.ghost:
        background = scheme.primary.withValues(alpha: 0.10);
        foreground = scheme.primary;
        border = null;
    }

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: foreground),
          const SizedBox(width: Insets.sm + 2),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelLarge?.copyWith(
              color: foreground,
              fontSize: widget.compact ? 13.5 : 14.5,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(Radii.sm + 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (value) {
                if (_pressed == value) return;
                setState(() => _pressed = value);
              },
              splashColor: foreground.withValues(alpha: 0.10),
              highlightColor: foreground.withValues(alpha: 0.06),
              child: Container(
                width: widget.expand ? double.infinity : null,
                height: widget.compact ? 44 : 52,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? Insets.lg : Insets.xl,
                ),
                decoration: BoxDecoration(
                  border: border,
                  borderRadius: BorderRadius.circular(Radii.sm + 2),
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular de icono para barras superiores.
class BelIconButton extends StatelessWidget {
  const BelIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled
            ? AppColors.marronOscuro.withValues(alpha: 0.42)
            : palette.surface.withValues(alpha: 0.86),
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: palette.border.withValues(alpha: 0.8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: filled ? AppColors.blancoCalido : palette.text,
            ),
          ),
        ),
      ),
    );
  }
}

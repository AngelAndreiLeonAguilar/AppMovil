import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Encabezado de sección: antetítulo, título y acción opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
    this.onAction,
    this.actionLabel,
    this.padding = const EdgeInsets.only(bottom: Insets.lg),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onAction;
  final String? actionLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: context.eyebrowStyle),
                  const SizedBox(height: Insets.sm),
                ],
                Text(title, style: texts.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: Insets.xs + 2),
                  Text(subtitle!, style: texts.bodyMedium),
                ],
              ],
            ),
          ),
          ?action,
          if (action == null && actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.xs,
                ),
                minimumSize: const Size(0, Insets.touch),
                textStyle: context.texts.labelMedium,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

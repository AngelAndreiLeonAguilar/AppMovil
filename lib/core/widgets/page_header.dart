import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'bel_button.dart';
import 'theme_toggle.dart';

/// Encabezado de pantalla: antetítulo, título grande y acciones.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showThemeToggle = true,
    this.showBack = false,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showThemeToggle;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          Insets.lg,
          Insets.page,
          Insets.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBack) ...[
                  BelIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: Insets.md),
                ],
                Expanded(
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: context.eyebrowStyle.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ),
                ...actions,
                if (actions.isNotEmpty && showThemeToggle)
                  const SizedBox(width: Insets.sm),
                if (showThemeToggle) const ThemeToggleButton(),
                ?trailing,
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(title, style: context.texts.displaySmall),
            if (subtitle != null) ...[
              const SizedBox(height: Insets.sm),
              Text(subtitle!, style: context.texts.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bel_button.dart';
import '../../../core/widgets/bel_tag.dart';

/// Encabezado de sección dentro de un formulario largo.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Material (y no DecoratedBox) para que los ListTile e InkWell internos
    // dibujen su efecto al tocarlos.
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: context.colors.primary),
                    const SizedBox(width: Insets.sm),
                  ],
                  Expanded(
                    child: Text(title, style: context.texts.titleMedium),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: Insets.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta en mayúsculas igual a la de [BelTextField].
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        text.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textMuted,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// Número con botones − y + (cupo, existencias, años…).
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.unit,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.texts.bodyMedium)),
        _RoundButton(
          icon: Icons.remove_rounded,
          tooltip: 'Menos',
          onTap: value - step >= min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 76,
          child: Text(
            unit == null ? '$value' : '$value $unit',
            textAlign: TextAlign.center,
            style: context.texts.titleMedium,
          ),
        ),
        _RoundButton(
          icon: Icons.add_rounded,
          tooltip: 'Más',
          onTap: value + step <= max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? context.colors.primary.withValues(alpha: 0.12)
            : context.palette.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? context.colors.primary
                  : context.palette.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selección de opciones con chips, con opción de escribir una propia.
class ChipPicker extends StatelessWidget {
  const ChipPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiple = true,
    this.allowCustom = true,
    this.customLabel = 'Otra…',
    this.customHint = 'Escribe la opción',
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool multiple;
  final bool allowCustom;
  final String customLabel;
  final String customHint;

  Future<void> _addCustom(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(customLabel.replaceAll('…', '')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: customHint),
          onSubmitted: (text) => Navigator.of(dialogContext).pop(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return;
    if (multiple) {
      if (!selected.contains(clean)) onChanged([...selected, clean]);
    } else {
      onChanged([clean]);
    }
  }

  void _toggle(String option) {
    if (!multiple) {
      onChanged([option]);
      return;
    }
    onChanged(
      selected.contains(option)
          ? [...selected.where((item) => item != option)]
          : [...selected, option],
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      ...options,
      for (final item in selected)
        if (!options.contains(item)) item,
    ];
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final option in all)
          BelFilterChip(
            label: option,
            selected: selected.contains(option),
            onTap: () => _toggle(option),
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
          ),
        if (allowCustom)
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(customLabel),
            onPressed: () => _addCustom(context),
          ),
      ],
    );
  }
}

/// Interruptor con título y explicación.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.texts.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.colors.onPrimary,
              activeTrackColor: context.colors.primary,
              inactiveTrackColor: palette.surfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pregunta antes de salir de un formulario con cambios sin guardar.
Future<bool> confirmDiscard(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Salir sin guardar?'),
      content: const Text('Los cambios que hiciste se perderán.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Seguir editando'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Salir',
            style: TextStyle(color: dialogContext.colors.error),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Barra fija inferior con el botón de guardar.
class FormSaveBar extends StatelessWidget {
  const FormSaveBar({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            Insets.md,
          ),
          child: BelButton(
            label: label,
            icon: Icons.check_rounded,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

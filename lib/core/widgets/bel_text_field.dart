import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Campo de texto con la identidad de Bel-Aaktun.
class BelTextField extends StatelessWidget {
  const BelTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.helper,
    this.prefixText,
    this.suffixText,
    this.maxLength,
    this.minLines,
    this.enabled = true,
    this.suffix,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  /// Texto de ayuda bajo el campo.
  final String? helper;
  final String? prefixText;
  final String? suffixText;
  final int? maxLength;
  final int? minLines;
  final bool enabled;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;

    OutlineInputBorder border(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.texts.labelSmall?.copyWith(
            color: palette.textMuted,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: Insets.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          minLines: minLines,
          enabled: enabled,
          cursorColor: scheme.primary,
          style: context.texts.bodyLarge?.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            helperStyle: context.texts.bodySmall?.copyWith(
              color: palette.textFaint,
              fontSize: 11.5,
            ),
            prefixText: prefixText,
            suffixText: suffixText,
            suffixIcon: suffix,
            hintStyle: context.texts.bodyMedium?.copyWith(
              color: palette.textFaint,
            ),
            filled: true,
            fillColor: palette.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.lg,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 19, color: palette.textMuted),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            border: border(palette.border, 1.2),
            enabledBorder: border(palette.border, 1.2),
            focusedBorder: border(scheme.primary, 1.6),
            errorBorder: border(scheme.error, 1.2),
            focusedErrorBorder: border(scheme.error, 1.6),
            errorStyle: context.texts.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      ],
    );
  }
}

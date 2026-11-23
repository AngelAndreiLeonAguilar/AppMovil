import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_text_field.dart';
import 'artisan_application_screen.dart';

/// Registro público de turista (el backend fuerza este rol).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.artisan = false});

  /// Preselecciona "Tengo un taller".
  final bool artisan;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late bool _artisan = widget.artisan;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.app.register(
      nombre: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      telefono: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (_artisan) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const ArtisanApplicationScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crear cuenta', style: context.texts.titleLarge),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.sm,
            Insets.page,
            Insets.x4l,
          ),
          children: [
            Text(
              '¿Cómo usarás Bel-Aaktun?',
              style: context.texts.titleMedium,
            ),
            const SizedBox(height: Insets.sm),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Soy visitante'),
                  icon: Icon(Icons.luggage_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Tengo un taller'),
                  icon: Icon(Icons.storefront_outlined),
                ),
              ],
              selected: {_artisan},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _artisan = value.first),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              _artisan
                  ? 'Primero creas tu cuenta y en el siguiente paso registras '
                        'tu taller.'
                  : 'Con tu cuenta reservas visitas y sigues tus solicitudes.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.xl),
            BelTextField(
              label: 'Nombre completo',
              hint: 'Como quieres que te llamemos',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              validator: (value) => (value ?? '').trim().length < 3
                  ? 'Escribe tu nombre completo.'
                  : null,
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Correo',
              hint: 'tucorreo@ejemplo.mx',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = (value ?? '').trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Escribe un correo válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: _artisan ? 'Teléfono' : 'Teléfono (opcional)',
              hint: '981 123 4567',
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty && !_artisan) return null;
                return digits.length < 10
                    ? 'Escribe un teléfono de 10 dígitos.'
                    : null;
              },
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Contraseña',
              hint: 'Mínimo 8, con letras y números',
              controller: _password,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              suffix: IconButton(
                tooltip: _showPassword
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8) return 'Mínimo 8 caracteres.';
                if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'\d').hasMatch(text)) {
                  return 'Combina letras y números.';
                }
                return null;
              },
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Confirmar contraseña',
              controller: _confirm,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              validator: (value) => value != _password.text
                  ? 'Las contraseñas no coinciden.'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(
                _error!,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ],
            const SizedBox(height: Insets.xl),
            BelButton(
              label: _loading
                  ? 'Creando cuenta…'
                  : (_artisan ? 'Crear cuenta y seguir' : 'Crear cuenta'),
              icon: Icons.check_rounded,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_text_field.dart';
import '../../core/config/app_config.dart';
import '../artisan/widgets/form_parts.dart';
import 'register_screen.dart';

/// Solicitud de verificación de un taller.
///
/// Requiere una cuenta (turista) iniciada; si no hay sesión, invita a crearla.
class ArtisanApplicationScreen extends StatefulWidget {
  const ArtisanApplicationScreen({super.key});

  @override
  State<ArtisanApplicationScreen> createState() =>
      _ArtisanApplicationScreenState();
}

class _ArtisanApplicationScreenState extends State<ArtisanApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  List<String> _craft = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.app.submitArtisanApplication(
      nombreTaller: _name.text.trim(),
      descripcion: _description.text.trim(),
      ubicacion: _location.text.trim(),
      direccion: _address.text.trim(),
      telefono: _phone.text.trim(),
      oficio: _craft.isEmpty ? null : _craft.first,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    final approved = context.app.isArtisan;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? '¡Listo! Tu taller ya está activo. Completa tu perfil y sube '
                    'fotos de tus piezas.'
              : 'Solicitud enviada. Te avisaremos cuando la revisen.',
        ),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;

    if (!app.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text('Verificar taller')),
        body: Padding(
          padding: const EdgeInsets.all(Insets.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Para solicitar la verificación necesitas una cuenta.',
                style: context.texts.titleMedium,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Crea tu cuenta (turista) y después envía los datos de tu '
                'taller. La administración revisará la información antes de '
                'darte acceso al panel.',
                style: context.texts.bodyMedium?.copyWith(
                  color: palette.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: Insets.xl),
              BelButton(
                label: 'Crear cuenta',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(artisan: true),
                  ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              BelButton(
                label: 'Ya tengo cuenta',
                variant: BelButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final pending = app.application;
    if (pending != null && pending.isPending) {
      return Scaffold(
        appBar: AppBar(title: Text('Verificar taller')),
        body: Padding(
          padding: const EdgeInsets.all(Insets.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tu solicitud ya está en revisión',
                style: context.texts.titleLarge,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Taller: ${pending.nombreTaller}. La administración la revisará '
                'y te avisaremos; mientras tanto no puedes publicar productos '
                'ni recibir reservas como taller verificado.',
                style: context.texts.bodyMedium?.copyWith(
                  color: palette.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: Insets.xl),
              BelButton(
                label: 'Volver',
                variant: BelButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Verificar taller')),
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
              app.isLocalMode && AppConfig.autoApproveArtisans
                  ? 'Cuéntanos de tu taller. Al enviar, tu panel de taller '
                        'se activa al momento para que empieces a subir tus '
                        'piezas y experiencias.'
                  : 'Cuéntanos de tu taller. La verificación evita que '
                        'alguien se haga pasar por un negocio artesanal.',
              style: context.texts.bodyMedium?.copyWith(
                color: palette.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.xl),
            BelTextField(
              label: 'Nombre del taller',
              hint: 'Cueva La Esperanza',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) => (value ?? '').trim().length < 3
                  ? 'Escribe el nombre del taller.'
                  : null,
            ),
            const SizedBox(height: Insets.lg),
            const FieldLabel('¿A qué te dedicas?'),
            ChipPicker(
              options: const [
                'Tejedora de Jipi Japa',
                'Sombrerero tradicional',
                'Bolsos y fibras',
                'Miniaturas y decoración',
              ],
              selected: _craft,
              multiple: false,
              customLabel: 'Otro oficio…',
              onChanged: (value) => setState(() => _craft = value),
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Descripción',
              hint: 'Qué hace el taller, qué se puede visitar, desde cuándo...',
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => (value ?? '').trim().length < 20
                  ? 'Describe el taller con al menos 20 caracteres.'
                  : null,
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Ubicación',
              hint: 'Bécal, Campeche',
              controller: _location,
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Dirección o referencia',
              hint: 'Calle 20 x 15, Centro',
              controller: _address,
            ),
            const SizedBox(height: Insets.lg),
            BelTextField(
              label: 'Teléfono o WhatsApp',
              hint: '981 123 4567',
              controller: _phone,
              keyboardType: TextInputType.phone,
              helper: 'Los turistas lo usarán para contactarte.',
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                return digits.length < 10
                    ? 'Escribe un teléfono de 10 dígitos.'
                    : null;
              },
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
              label: _loading ? 'Enviando…' : 'Enviar solicitud',
              icon: Icons.send_rounded,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: Insets.lg),
            BelSurface(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(
                'Después podrás subir la foto de tu taller, tu portada y las '
                'fotos de tus piezas desde la pestaña Perfil y Catálogo.',
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textFaint,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

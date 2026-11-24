import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/bel_text_field.dart';
import '../account/test_server_card.dart';
import 'register_screen.dart';
import '../../core/widgets/bel_logo.dart';

/// Inicio de sesión contra la API real.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context.app.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Future<void> _openServerSettings() async {
    final app = context.app;
    final controller = TextEditingController(text: app.apiBaseUrl);
    String? message;
    var working = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: dialogContext.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Servidor de la API',
            style: dialogContext.texts.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Si la app no conecta, revisa que el servidor esté encendido. '
                'Desde un teléfono usa la IP de tu computadora, por ejemplo '
                'http://192.168.1.50:5001/api/v1',
                style: dialogContext.texts.bodySmall,
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                cursorColor: dialogContext.colors.primary,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.50:5001/api/v1',
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  message!,
                  style: dialogContext.texts.bodySmall?.copyWith(
                    color: dialogContext.colors.primary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: working
                  ? null
                  : () async {
                      setDialogState(() {
                        working = true;
                        message = 'Probando…';
                      });
                      final error = await app.testConnectionAt(controller.text);
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        working = false;
                        message = error ?? 'Conexión correcta.';
                      });
                    },
              child: const Text('Probar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: working
                  ? null
                  : () async {
                      setDialogState(() => working = true);
                      final error = await app.setApiBaseUrl(controller.text);
                      if (!dialogContext.mounted) return;
                      if (error != null) {
                        setDialogState(() {
                          working = false;
                          message = error;
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.page,
                    Insets.x4l,
                    Insets.page,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BelLogo(size: 96),
                      const SizedBox(height: Insets.lg),
                      Text(
                        'PLATAFORMA ARTESANAL',
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.primary,
                          letterSpacing: 3,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        'Bel·Aaktun',
                        style: context.texts.displayMedium?.copyWith(
                          fontSize: 44,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        'Entra para reservar una visita o administrar tu '
                        'taller verificado.',
                        style: context.texts.bodyMedium?.copyWith(
                          color: palette.textMuted,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.page,
                    Insets.x3l,
                    Insets.page,
                    0,
                  ),
                  child: BelSurface(
                    padding: const EdgeInsets.all(Insets.lg),
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BelTextField(
                          label: 'Correo',
                          hint: 'tucorreo@ejemplo.mx',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.alternate_email_rounded,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (!text.contains('@') || text.length < 5) {
                              return 'Escribe un correo válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: Insets.lg),
                        BelTextField(
                          label: 'Contraseña',
                          hint: '••••••••',
                          controller: _passwordController,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: (value) {
                            if ((value ?? '').length < 8) {
                              return 'Mínimo 8 caracteres.';
                            }
                            return null;
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
                          label: _loading ? 'Entrando…' : 'Entrar',
                          icon: Icons.login_rounded,
                          onPressed: _loading ? null : _submit,
                        ),
                        const SizedBox(height: Insets.sm),
                        BelButton(
                          label: 'Crear cuenta',
                          icon: Icons.person_add_alt_1_rounded,
                          variant: BelButtonVariant.ghost,
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.page,
                    Insets.xl,
                    Insets.page,
                    0,
                  ),
                  child: BelSurface(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: context.colors.secondary,
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: Text(
                                '¿Tienes un taller artesanal?',
                                style: context.texts.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'Crea tu cuenta y registra tu taller para publicar '
                          'tus piezas y recibir reservas.',
                          style: context.texts.bodySmall?.copyWith(
                            color: palette.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        BelButton(
                          label: 'Registrar mi taller',
                          icon: Icons.verified_outlined,
                          variant: BelButtonVariant.outline,
                          compact: true,
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const RegisterScreen(artisan: true),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (context.app.isLocalMode || context.app.isSharedMode)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      Insets.page,
                      Insets.xl,
                      Insets.page,
                      0,
                    ),
                    child: TestServerCard(),
                  ),
                ),
              if (!context.app.isLocalMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.page,
                      Insets.xl,
                      Insets.page,
                      0,
                    ),
                    child: BelSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dns_outlined,
                            size: 16,
                            color: palette.textMuted,
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SERVIDOR',
                                  style: context.texts.labelSmall?.copyWith(
                                    color: palette.textFaint,
                                    letterSpacing: 1.6,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  context.app.apiBaseUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodySmall?.copyWith(
                                    color: palette.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (context.app.canChangeApiBaseUrl)
                            TextButton(
                              onPressed: _openServerSettings,
                              child: const Text('Cambiar'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.page,
                    Insets.xl,
                    Insets.page,
                    Insets.x4l,
                  ),
                  child: Column(
                    children: [
                      if (AppConfig.showDemoBadges)
                        const BelPill(
                          label: 'Versión de prueba · pagos en el taller',
                          icon: Icons.science_outlined,
                        ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        'Al continuar aceptas que tus datos se usen para '
                        'gestionar reservaciones y verificaciones de taller.',
                        textAlign: TextAlign.center,
                        style: context.texts.bodySmall?.copyWith(
                          color: palette.textFaint,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

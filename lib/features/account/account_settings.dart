import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import 'test_server_card.dart';

/// Ajustes de la cuenta: datos, apariencia, avisos, contraseña y salida.
class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final user = app.user;
    final palette = context.palette;
    final theme = ThemeScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupTitle('Mi cuenta'),
        BelSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Tile(
                icon: Icons.person_outline_rounded,
                title: user?.name ?? '',
                subtitle: [
                  user?.email ?? '',
                  if ((user?.phone ?? '').isNotEmpty) user!.phone!,
                ].join(' · '),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editAccount(context),
              ),
              const Divider(height: 1),
              _Tile(
                icon: Icons.lock_outline_rounded,
                title: 'Cambiar contraseña',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _changePassword(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        _GroupTitle('Preferencias'),
        BelSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Modo oscuro',
                subtitle: 'Más cómodo de noche. Por defecto se usa el claro.',
                value: theme.isDark,
                onChanged: (value) => theme.setMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Avisos en el teléfono',
                subtitle:
                    'Nuevas reservas, confirmaciones y recordatorios en la '
                    'barra de notificaciones.',
                value: app.deviceNotificationsEnabled,
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final enabled = await app.setDeviceNotificationsEnabled(
                    value,
                  );
                  if (value && !enabled) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El teléfono no dio permiso. Actívalo en Ajustes > '
                          'Notificaciones > Bel-Aaktun.',
                        ),
                      ),
                    );
                  }
                },
              ),
              if (app.deviceNotificationsEnabled) ...[
                const Divider(height: 1),
                _Tile(
                  icon: Icons.send_outlined,
                  title: 'Enviar aviso de prueba',
                  subtitle: 'Comprueba que las notificaciones llegan.',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await app.sendTestNotification();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Revisa la barra de notificaciones.'),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (app.isLocalMode || app.isSharedMode) ...[
          const SizedBox(height: Insets.lg),
          const TestServerCard(),
        ],
        const SizedBox(height: Insets.xl),
        BelButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          variant: BelButtonVariant.outline,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('¿Cerrar sesión?'),
                content: const Text(
                  'Tus datos se quedan guardados. Podrás volver a entrar con '
                  'tu correo y contraseña.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            final navigator = Navigator.of(context);
            await context.app.signOut();
            navigator.popUntil((route) => route.isFirst);
          },
        ),
        if (app.isLocalMode && !app.isSharedMode) ...[
          const SizedBox(height: Insets.md),
          Text(
            'Versión de pruebas: tu cuenta y tus datos se guardan solo en este '
            'teléfono.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textFaint,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editAccount(BuildContext context) async {
    final app = context.app;
    final user = app.user;
    if (user == null) return;
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone ?? '');
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Mis datos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              if (error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  error!,
                  style: TextStyle(color: dialogContext.colors.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final result = await app.updateMyAccount(
                  name: name.text,
                  phone: phone.text,
                );
                if (!dialogContext.mounted) return;
                if (result != null) {
                  setState(() => error = result);
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final app = context.app;
    final current = TextEditingController();
    final next = TextEditingController();
    String? error;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Mínimo 8, con letras y números',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  error!,
                  style: TextStyle(color: dialogContext.colors.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final text = next.text;
                if (text.length < 8 ||
                    !RegExp(r'[A-Za-z]').hasMatch(text) ||
                    !RegExp(r'\d').hasMatch(text)) {
                  setState(
                    () => error = 'Usa mínimo 8 caracteres con letras y '
                        'números.',
                  );
                  return;
                }
                final result = await app.changePassword(current.text, text);
                if (!dialogContext.mounted) return;
                if (result != null) {
                  setState(() => error = result);
                } else {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
      );
    }
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm, left: Insets.xs),
      child: Text(
        text.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textMuted,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.palette.textMuted),
      title: Text(title, style: context.texts.bodyLarge),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(
              subtitle!,
              style: context.texts.bodySmall?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: context.palette.textMuted),
      title: Text(title, style: context.texts.bodyLarge),
      subtitle: Text(
        subtitle,
        style: context.texts.bodySmall?.copyWith(
          color: context.palette.textMuted,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: context.colors.onPrimary,
      activeTrackColor: context.colors.primary,
    );
  }
}

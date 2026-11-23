import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/photo_picker.dart';
import '../../domain/user.dart';
import '../auth/artisan_application_screen.dart';
import 'account_settings.dart';

/// "Mi cuenta" del turista: foto, datos, preferencias y salida.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final user = app.user;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text('Mi cuenta', style: context.texts.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          Insets.md,
          Insets.page,
          Insets.x4l,
        ),
        children: [
          Center(
            child: AvatarEditor(
              path: app.myAvatar,
              size: 112,
              onChanged: (path) => app.setMyAvatar(path),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            user?.name ?? '',
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall,
          ),
          Text(
            user?.role.label ?? '',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: Insets.xl),
          if (user?.role == UserRole.tourist) ...[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(color: palette.border),
              ),
              leading: Icon(
                Icons.storefront_outlined,
                color: context.colors.secondary,
              ),
              title: const Text('¿Tienes un taller artesanal?'),
              subtitle: const Text('Registra tu taller y recibe reservas.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ArtisanApplicationScreen(),
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),
          ],
          const AccountSettingsSection(),
        ],
      ),
    );
  }
}

/// Botón redondo con la foto del usuario que abre [AccountScreen].
class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Semantics(
      button: true,
      label: 'Mi cuenta',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.palette.border, width: 1.5),
          ),
          child: ClipOval(
            child: BelArtwork(
              imagePath: app.myAvatar,
              variant: ArtworkVariant.portrait,
              icon: app.myAvatar == null ? Icons.person_rounded : null,
            ),
          ),
        ),
      ),
    );
  }
}

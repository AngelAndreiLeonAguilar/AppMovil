import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../domain/artisan_application.dart';
import 'artisan_application_screen.dart';

/// Estado de la solicitud de verificación del taller.
class ApplicationStatusScreen extends StatelessWidget {
  const ApplicationStatusScreen({super.key, this.onExplore});

  /// Si se define, permite volver a la app como turista mientras se revisa.
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final application = app.application;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.x3l,
            Insets.page,
            Insets.x4l,
          ),
          children: [
            Text(
              'VERIFICACIÓN DE TALLER',
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.primary,
                letterSpacing: 3,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: Insets.md),
            Text('Tu solicitud', style: context.texts.displaySmall),
            const SizedBox(height: Insets.sm),
            Text(
              application == null
                  ? 'Aún no has enviado una solicitud de taller.'
                  : 'La administración revisa los datos antes de habilitar '
                        'tu panel. Esto evita suplantaciones.',
              style: context.texts.bodyMedium?.copyWith(
                color: palette.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.xl),

            if (application != null) ...[
              BelSurface(
                padding: const EdgeInsets.all(Insets.lg),
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            application.nombreTaller,
                            style: context.texts.titleLarge,
                          ),
                        ),
                        _EstadoPill(application: application),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      application.creadoEn == null
                          ? 'Solicitud #${application.id}'
                          : 'Solicitud #${application.id} · enviada el '
                                '${formatLongDate(application.creadoEn!)}',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                    if (application.isPending) ...[
                      const SizedBox(height: Insets.md),
                      Text(
                        'Mientras la solicitud está pendiente, tu cuenta sigue '
                        'siendo de turista: no puedes publicar productos ni '
                        'recibir reservas como taller verificado.',
                        style: context.texts.bodySmall?.copyWith(
                          color: palette.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (application.isRejected) ...[
                      const SizedBox(height: Insets.md),
                      Text(
                        'Motivo del rechazo',
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.error,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        application.motivoRechazo ?? 'Sin motivo registrado.',
                        style: context.texts.bodySmall?.copyWith(height: 1.45),
                      ),
                    ],
                    if (application.isApproved) ...[
                      const SizedBox(height: Insets.md),
                      Text(
                        '¡Taller verificado! Vuelve a cargar tu perfil para '
                        'entrar al panel.',
                        style: context.texts.bodySmall?.copyWith(
                          color: context.colors.primary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],

            BelButton(
              label: 'Actualizar estado',
              icon: Icons.refresh_rounded,
              variant: BelButtonVariant.outline,
              onPressed: app.refreshProfile,
            ),

            if (onExplore != null) ...[
              const SizedBox(height: Insets.sm),
              BelButton(
                label: 'Explorar mientras tanto',
                icon: Icons.explore_outlined,
                onPressed: onExplore,
              ),
            ],

            if (application == null || application.isRejected) ...[
              const SizedBox(height: Insets.sm),
              BelButton(
                label: 'Enviar solicitud de taller',
                icon: Icons.storefront_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ArtisanApplicationScreen(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: Insets.xl),
            BelButton(
              label: 'Cerrar sesión',
              icon: Icons.logout_rounded,
              variant: BelButtonVariant.ghost,
              onPressed: app.signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoPill extends StatelessWidget {
  const _EstadoPill({required this.application});

  final ArtisanApplication application;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (application.estado) {
      'aprobada' => ('Aprobada', const Color(0xFF4E7A5A)),
      'rechazada' => ('Rechazada', context.colors.error),
      'en_revision' => ('En revisión', context.colors.secondary),
      'suspendida' => ('Suspendida', context.colors.error),
      'retirada' => ('Retirada', context.palette.textMuted),
      _ => ('Pendiente', context.colors.secondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall?.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_links.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/photo_picker.dart';
import '../../data/models.dart';
import '../account/account_settings.dart';
import '../artisans/artisan_detail_screen.dart';
import 'profile_edit_screen.dart';
import 'widgets/profile_progress_card.dart';

/// Perfil del negocio: ficha pública, avance y ajustes de la cuenta.
class ArtisanProfileScreen extends StatelessWidget {
  const ArtisanProfileScreen({super.key});

  static Future<void> openEditor(BuildContext context) async {
    final artisan = context.app.artisan;
    if (artisan == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ArtisanProfileEditScreen(artisan: artisan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final artisan = app.artisan;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Mi negocio',
            title: 'Perfil',
            subtitle: 'Así te conocen los turistas.',
            showThemeToggle: false,
          ),
        ),

        if (artisan == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Insets.page),
              child: Text(
                'No encontramos la ficha de tu taller. Cierra sesión y vuelve '
                'a entrar.',
                style: context.texts.bodyMedium,
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _ShopHeader(artisan: artisan)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.lg,
                Insets.page,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: BelButton(
                      label: 'Editar perfil',
                      icon: Icons.edit_outlined,
                      compact: true,
                      onPressed: () => openEditor(context),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: BelButton(
                      label: 'Ver como turista',
                      icon: Icons.visibility_outlined,
                      compact: true,
                      variant: BelButtonVariant.outline,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArtisanDetailScreen(
                            artisan: artisan,
                            heroTag: 'preview-${artisan.id}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Insets.page,
                Insets.lg,
                Insets.page,
                0,
              ),
              child: ProfileProgressCard(hideWhenComplete: false),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.lg,
                Insets.page,
                0,
              ),
              child: _ContactCard(artisan: artisan),
            ),
          ),
          if (!artisan.isPublished)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.md,
                  Insets.page,
                  0,
                ),
                child: BelSurface(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, color: palette.textMuted),
                      const SizedBox(width: Insets.sm),
                      const Expanded(
                        child: Text(
                          'Tu taller está oculto para los turistas. '
                          'Actívalo en "Editar perfil".',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],

        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(Insets.page, Insets.xl, Insets.page, 0),
            child: AccountSettingsSection(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.artisan});

  final Artisan artisan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final app = context.app;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.page),
      child: BelSurface(
        padding: EdgeInsets.zero,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.md),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await pickSinglePhoto(context);
                        if (picked == null || !context.mounted) return;
                        await app.updateArtisanProfile(
                          artisan.copyWith(coverPath: picked),
                        );
                      },
                      child: BelArtwork(
                        imagePath: artisan.coverPath,
                        variant: ArtworkVariant.cave,
                        seed: artisan.id.hashCode,
                        icon: artisan.coverPath == null
                            ? Icons.add_photo_alternate_outlined
                            : null,
                        label: 'Portada del taller',
                      ),
                    ),
                  ),
                  Positioned(
                    left: Insets.lg,
                    bottom: -40,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.surface, width: 4),
                      ),
                      child: AvatarEditor(
                        path: artisan.imagePath,
                        size: 84,
                        onChanged: (path) => app.setMyAvatar(path),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.x3l + Insets.sm,
                Insets.lg,
                Insets.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artisan.name, style: context.texts.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    artisan.craft,
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    [
                      if (artisan.yearsOfCraft > 0)
                        '${artisan.yearsOfCraft} años de oficio',
                      if (artisan.cave.isNotEmpty) artisan.cave,
                    ].join(' · '),
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      _Stat(
                        value: '${app.myProducts.length}',
                        label: 'piezas',
                      ),
                      _Stat(
                        value: '${app.myServices.length}',
                        label: 'experiencias',
                      ),
                      _Stat(
                        value: '${app.counters.completed}',
                        label: 'visitas',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.texts.titleLarge),
          Text(
            label,
            style: context.texts.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.artisan});

  final Artisan artisan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final schedule = scheduleLabel(artisan);
    final lines = <(IconData, String)>[
      if ((artisan.phone ?? '').isNotEmpty) (Icons.phone_outlined, artisan.phone!),
      if ((artisan.whatsapp ?? '').isNotEmpty &&
          artisan.whatsapp != artisan.phone)
        (Icons.chat_outlined, 'WhatsApp ${artisan.whatsapp}'),
      if ((artisan.email ?? '').isNotEmpty)
        (Icons.mail_outline_rounded, artisan.email!),
      if ((artisan.address ?? '').isNotEmpty)
        (Icons.place_outlined, artisan.address!),
      if (schedule != null) (Icons.schedule_rounded, schedule),
      if (artisan.paymentMethods.isNotEmpty)
        (Icons.payments_outlined, artisan.paymentMethods.join(', ')),
      if (artisan.languages.isNotEmpty)
        (Icons.translate_rounded, artisan.languages.join(', ')),
    ];

    return BelSurface(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTACTO Y HORARIO',
            style: context.texts.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: Insets.md),
          if (lines.isEmpty)
            Text(
              'Aún no agregas teléfono ni horario. Los turistas no sabrán '
              'cómo contactarte.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            )
          else
            for (final (icon, text) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: palette.textMuted),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: context.texts.bodySmall?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

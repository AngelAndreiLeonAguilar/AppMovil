import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/app_tabs.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/reveal.dart';
import '../../data/models.dart';
import 'artisan_detail_screen.dart';
import '../../core/widgets/service_status_badge.dart';

/// Directorio de artesanos de Bécal.
class ArtisansScreen extends StatelessWidget {
  const ArtisansScreen({super.key, required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Manos que tejen',
            title: 'Artesanos',
            subtitle:
                'Talleres familiares que abren sus cuevas para compartir '
                'el oficio.',
          ),
        ),
        SliverList.builder(
          itemCount: context.app.artisans.length,
          itemBuilder: (context, index) {
            final artisan = context.app.artisans[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xs,
                Insets.page,
                Insets.md,
              ),
              child: Reveal(
                index: index,
                child: _ArtisanRow(
                  artisan: artisan,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArtisanDetailScreen(
                          artisan: artisan,
                          onBook: () {
                            Navigator.of(context).pop();
                            onSelectTab(AppTabs.booking);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.lg,
              Insets.page,
              132,
            ),
            child: Text(
              '¿Eres artesano de Bécal? Escríbenos para sumar tu taller a la ruta.',
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtisanRow extends StatelessWidget {
  const _ArtisanRow({required this.artisan, required this.onTap});

  final Artisan artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BelSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'artisan-${artisan.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm + 2),
              child: SizedBox(
                width: 78,
                height: 78,
                child: BelArtwork(
                  imagePath: artisan.imagePath,
                  variant: ArtworkVariant.portrait,
                  seed: artisan.id.hashCode,
                  label: artisan.name,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(artisan.name, style: context.texts.titleLarge),
                const SizedBox(height: 2),
                Text(artisan.craft, style: context.texts.bodySmall),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: [
                    ServiceStatusBadge(artisanId: artisan.id),
                    BelPill(
                      label: artisan.cave.replaceFirst('Cueva ', ''),
                      icon: Icons.terrain_outlined,
                      color: context.colors.secondary,
                    ),
                    if (artisan.yearsOfCraft > 0)
                      BelPill(
                        label: '${artisan.yearsOfCraft} años',
                        icon: Icons.auto_awesome_outlined,
                      ),
                    if (AppConfig.showDemoBadges &&
                        context.app.isSampleArtisan(artisan.id))
                      const BelPill(
                        label: 'Ejemplo',
                        icon: Icons.science_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.palette.textFaint,
          ),
        ],
      ),
    );
  }
}

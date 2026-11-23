import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_surface.dart';
import '../../../data/models.dart';

/// Ficha compacta de artesano para carruseles.
class ArtisanCard extends StatelessWidget {
  const ArtisanCard({
    super.key,
    required this.artisan,
    this.onTap,
    this.width = 236,
    this.heroTag,
  });

  final Artisan artisan;
  final VoidCallback? onTap;
  final double width;

  /// Etiqueta del [Hero]. Por defecto `artisan-<id>`; el inicio usa la suya
  /// porque convive con la pantalla de artesanos en el mismo shell.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: BelSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        radius: Radii.md,
        child: Row(
          children: [
            Hero(
              tag: heroTag ?? 'artisan-${artisan.id}',
              child: ClipOval(
                child: SizedBox(
                  width: 58,
                  height: 58,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artisan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artisan.craft,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    '${artisan.yearsOfCraft} años de oficio',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.secondary,
                      letterSpacing: 0.6,
                      fontSize: 10,
                    ),
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

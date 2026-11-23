
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/bel_artwork.dart';
import '../../../core/widgets/bel_tag.dart';
import '../../../data/models.dart';

/// Tarjeta de producto artesanal, reutilizada en inicio y catálogo.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.artisan,
    this.onTap,
    this.width,
    this.heroTag,
  });

  final Product product;
  final Artisan? artisan;
  final VoidCallback? onTap;

  /// Ancho fijo para carruseles; null para rejillas.
  final double? width;

  /// Etiqueta del Hero compartido con el detalle.
  /// Debe ser única dentro de la ruta que la contiene.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _maybeHero(
                  heroTag,
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BelArtwork(
                          imagePath: product.coverImage,
                          variant: ArtworkVariant.craft,
                          seed: product.id.hashCode,
                          label: product.name,
                        ),

                        if (product.madeToOrder)
                          Positioned(
                            left: Insets.sm,
                            top: Insets.sm,
                            child: BelPill(
                              label: 'Por encargo',
                              icon: Icons.auto_awesome_outlined,
                              color: AppColors.blancoCalido,
                            ),
                          ),

                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.marronOscuro.withValues(alpha: 0.28),
                                ],
                                stops: const [0.6, 1],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: Insets.md),

              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleMedium,
              ),

              const SizedBox(height: 2),

              Text(
                artisan?.name ?? product.technique,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall,
              ),

              const SizedBox(height: Insets.sm),

              Text(
                formatPrice(product.price),
                style: context.texts.labelMedium?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Envuelve el contenido en Hero únicamente cuando existe una etiqueta.
Widget _maybeHero(String? tag, Widget child) {
  if (tag == null || tag.isEmpty) {
    return child;
  }

  return Hero(
    tag: tag,
    child: child,
  );
}

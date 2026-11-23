import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/photo_carousel.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../data/models.dart';
import '../../core/state/app_scope.dart';
import '../../core/utils/contact_links.dart';
import '../contact/contact_screen.dart';
import '../orders/cart_screen.dart';
import '../../core/config/app_config.dart';

/// Detalle de una pieza del catálogo.
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.artisan,
    this.onBook,
  });

  final Product product;
  final Artisan? artisan;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    // Versión más reciente (precio y existencias pueden cambiar).
    final product = context.app.productById(this.product.id) ?? this.product;
    final artisan = this.artisan ?? context.app.artisanById(product.artisanId);
    final inCart = context.app.cartQuantityOf(product.id);
    final askPrice = product.price == null;
    final buyLabel = product.isSoldOut
        ? 'Agotada'
        : askPrice
        ? 'Consultar precio'
        : inCart > 0
        ? 'Agregar otra ($inCart en carrito)'
        : 'Agregar al carrito';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 380,
            backgroundColor: palette.background,
            surfaceTintColor: Colors.transparent,
            foregroundColor: palette.text,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: Insets.md),
              child: Center(
                child: BelIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Volver',
                  filled: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: Insets.md),
                child: CartButton(filled: true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Hero(
                tag: 'product-${product.id}',
                child: PhotoCarousel(
                  photos: product.gallery,
                  variant: ArtworkVariant.craft,
                  seed: product.id.hashCode,
                  scrim: true,
                  label: product.name,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xxl,
                Insets.page,
                Insets.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    children: [
                      BelPill(
                        label: product.category,
                        icon: Icons.sell_outlined,
                        color: scheme.primary,
                      ),
                      if (AppConfig.showDemoBadges &&
                          context.app.isSampleArtisan(product.artisanId))
                        const BelPill(
                          label: 'Ejemplo',
                          icon: Icons.science_outlined,
                        ),
                      if (product.madeToOrder)
                        BelPill(
                          label: 'Hecho por encargo',
                          icon: Icons.auto_awesome_outlined,
                          color: scheme.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Text(product.name, style: context.texts.headlineLarge),
                  const SizedBox(height: Insets.sm),
                  Text(product.technique, style: context.quoteStyle(size: 19)),
                  const SizedBox(height: Insets.lg),
                  Text(product.description, style: context.texts.bodyLarge),
                  if (product.dimensions != null ||
                      product.materials.isNotEmpty ||
                      product.productionDays != null ||
                      product.stock != null) ...[
                    const SizedBox(height: Insets.lg),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        if (product.dimensions != null)
                          BelPill(
                            label: product.dimensions!,
                            icon: Icons.straighten_rounded,
                          ),
                        for (final material in product.materials)
                          BelPill(label: material, icon: Icons.grass_rounded),
                        if (product.madeToOrder &&
                            product.productionDays != null)
                          BelPill(
                            label:
                                'Lista en ${product.productionDays} '
                                '${product.productionDays == 1 ? 'día' : 'días'}',
                            icon: Icons.timer_outlined,
                          ),
                        if (!product.madeToOrder && product.stock != null)
                          BelPill(
                            label: product.isSoldOut
                                ? 'Agotada por ahora'
                                : '${product.stock} disponibles',
                            icon: Icons.inventory_2_outlined,
                            color: product.isSoldOut ? scheme.error : null,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Insets.xl),
                  const Divider(),
                  const SizedBox(height: Insets.xl),
                  if (artisan != null) ...[
                    Text('TEJIDA POR', style: context.eyebrowStyle),
                    const SizedBox(height: Insets.md),
                    BelSurface(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 54,
                              height: 54,
                              child: BelArtwork(
                                imagePath: artisan.imagePath,
                                variant: ArtworkVariant.portrait,
                                seed: artisan.id.hashCode,
                                label: artisan.name,
                              ),
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artisan.name,
                                  style: context.texts.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${artisan.craft} · ${artisan.cave}',
                                  style: context.texts.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  Text('Cuidados', style: context.texts.titleLarge),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Evita la humedad prolongada y guarda la pieza en un lugar '
                    'seco. La palma recupera su forma con el uso; si se deforma, '
                    'puedes humedecerla ligeramente y dejar secar en sombra.',
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: Insets.xl),
                  SizedBox(
                    width: double.infinity,
                    child: BelButton(
                      label: 'Preguntar por esta pieza',
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: BelButtonVariant.outline,
                      onPressed: (artisan?.whatsapp ?? '').isNotEmpty
                          ? () => ContactLinks.open(
                              context,
                              ContactLinks.whatsapp(
                                artisan!.whatsapp!,
                                message:
                                    'Hola, me interesa ${product.name} que vi '
                                    'en Bel-Aaktun.',
                              ),
                            )
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ContactScreen(
                                  presetMessage: 'Me interesa ${product.name}.',
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (onBook != null) ...[
                    const SizedBox(height: Insets.sm),
                    SizedBox(
                      width: double.infinity,
                      child: BelButton(
                        label: '¿Quieres ver cómo se teje? Reserva una visita',
                        icon: Icons.event_available_outlined,
                        variant: BelButtonVariant.ghost,
                        onPressed: onBook,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.md,
              Insets.page,
              Insets.md,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.madeToOrder ? 'POR ENCARGO' : 'PRECIO',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.textMuted,
                        letterSpacing: 1.6,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatPrice(product.price),
                      style: context.texts.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: BelButton(
                    label: buyLabel,
                    icon: askPrice
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.add_shopping_cart_rounded,
                    onPressed: product.isSoldOut
                        ? null
                        : askPrice
                        ? () => _askPrice(context, product, artisan)
                        : () => addToCartWithFeedback(context, product),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _askPrice(BuildContext context, Product product, Artisan? artisan) {
    final whatsapp = (artisan?.whatsapp ?? '').trim();
    if (whatsapp.isNotEmpty) {
      ContactLinks.open(
        context,
        ContactLinks.whatsapp(
          whatsapp,
          message:
              'Hola, vi "${product.name}" en Bel-Aaktun. ¿Cuál es su precio?',
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactScreen(
          presetMessage: '¿Cuál es el precio de ${product.name}?',
        ),
      ),
    );
  }
}

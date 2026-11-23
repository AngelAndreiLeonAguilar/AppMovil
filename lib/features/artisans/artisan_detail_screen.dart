import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/widgets/product_card.dart';
import '../contact/contact_screen.dart';

/// Perfil del artesano: oficio, técnicas y piezas.
class ArtisanDetailScreen extends StatelessWidget {
  const ArtisanDetailScreen({
    super.key,
    required this.artisan,
    this.onBook,
    this.heroTag,
  });

  final Artisan artisan;
  final VoidCallback? onBook;

  /// Etiqueta del [Hero] de origen. Inicio y Artesanos conviven en el shell,
  /// así que cada uno usa la suya para no duplicar etiquetas.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Siempre la versión más reciente (el taller puede editar su ficha).
    final artisan = context.app.artisanById(this.artisan.id) ?? this.artisan;
    final products = context.app.productsOf(artisan.id);
    final services = context.app.servicesOf(artisan.id);
    final schedule = scheduleLabel(artisan);
    final whatsapp = (artisan.whatsapp ?? '').trim();
    final phone = (artisan.phone ?? '').trim();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 360,
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
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Hero(
                tag: heroTag ?? 'artisan-${artisan.id}',
                child: BelArtwork(
                  imagePath: artisan.coverPath ?? artisan.imagePath,
                  variant: ArtworkVariant.portrait,
                  seed: artisan.id.hashCode,
                  scrim: true,
                  label: artisan.name,
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
                  Row(
                    children: [
                      if (artisan.coverPath != null &&
                          artisan.imagePath != null) ...[
                        ClipOval(
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: BelArtwork(
                              imagePath: artisan.imagePath,
                              variant: ArtworkVariant.portrait,
                              label: 'Foto de ${artisan.name}',
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artisan.craft.toUpperCase(),
                              style: context.eyebrowStyle,
                            ),
                            const SizedBox(height: Insets.sm),
                            Text(
                              artisan.name,
                              style: context.texts.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      BelPill(
                        label: artisan.cave,
                        icon: Icons.terrain_outlined,
                        color: context.colors.secondary,
                      ),
                      if (artisan.yearsOfCraft > 0)
                        BelPill(
                          label: '${artisan.yearsOfCraft} años de oficio',
                          icon: Icons.auto_awesome_outlined,
                        ),
                      for (final language in artisan.languages)
                        BelPill(
                          label: language,
                          icon: Icons.translate_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                  if (artisan.bio.trim().isNotEmpty) ...[
                    Text(artisan.bio, style: context.texts.bodyLarge),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (artisan.techniques.isNotEmpty) ...[
                    Text('Técnicas', style: context.texts.titleLarge),
                    const SizedBox(height: Insets.md),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        for (final technique in artisan.techniques)
                          BelPill(label: technique, icon: Icons.check_rounded),
                      ],
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (schedule != null ||
                      whatsapp.isNotEmpty ||
                      phone.isNotEmpty ||
                      (artisan.address ?? '').isNotEmpty ||
                      artisan.paymentMethods.isNotEmpty) ...[
                    BelSurface(
                      padding: const EdgeInsets.all(Insets.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Horario y contacto',
                            style: context.texts.titleMedium,
                          ),
                          const SizedBox(height: Insets.md),
                          if (schedule != null)
                            _InfoLine(
                              icon: Icons.schedule_rounded,
                              text: schedule,
                            ),
                          if ((artisan.address ?? '').isNotEmpty)
                            _InfoLine(
                              icon: Icons.place_outlined,
                              text: artisan.address!,
                            ),
                          if (artisan.paymentMethods.isNotEmpty)
                            _InfoLine(
                              icon: Icons.payments_outlined,
                              text:
                                  'Acepta: ${artisan.paymentMethods.join(', ')}',
                            ),
                          if (whatsapp.isNotEmpty || phone.isNotEmpty) ...[
                            const SizedBox(height: Insets.sm),
                            Row(
                              children: [
                                if (whatsapp.isNotEmpty)
                                  Expanded(
                                    child: BelButton(
                                      label: 'WhatsApp',
                                      icon: Icons.chat_rounded,
                                      compact: true,
                                      onPressed: () => ContactLinks.open(
                                        context,
                                        ContactLinks.whatsapp(
                                          whatsapp,
                                          message:
                                              'Hola, vi su taller en '
                                              'Bel-Aaktun y me gustaría '
                                              'más información.',
                                        ),
                                      ),
                                    ),
                                  ),
                                if (whatsapp.isNotEmpty && phone.isNotEmpty)
                                  const SizedBox(width: Insets.sm),
                                if (phone.isNotEmpty)
                                  Expanded(
                                    child: BelButton(
                                      label: 'Llamar',
                                      icon: Icons.call_outlined,
                                      compact: true,
                                      variant: BelButtonVariant.outline,
                                      onPressed: () => ContactLinks.open(
                                        context,
                                        ContactLinks.call(phone),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                  if (services.isNotEmpty) ...[
                    Text('Experiencias', style: context.texts.titleLarge),
                    const SizedBox(height: Insets.md),
                    for (final service in services) ...[
                      BelSurface(
                        padding: EdgeInsets.zero,
                        onTap: onBook,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(Radii.md),
                              ),
                              child: SizedBox(
                                width: 92,
                                height: 92,
                                child: BelArtwork(
                                  imagePath: service.coverImage,
                                  variant: ArtworkVariant.cave,
                                  seed: service.id.hashCode,
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Insets.sm,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatDuration(service.durationMinutes)}'
                                      ' · ${formatPrice(service.pricePerPerson)}'
                                      ' por persona',
                                      style: context.texts.bodySmall?.copyWith(
                                        color: palette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                    ],
                    const SizedBox(height: Insets.lg),
                  ],
                  BelSurface(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 20,
                          color: context.colors.secondary,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visita el taller',
                                style: context.texts.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${artisan.cave} · Bécal, Campeche',
                                style: context.texts.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'PIEZAS DE ${artisan.name.split(' ').last.toUpperCase()}',
                      style: context.texts.labelSmall?.copyWith(
                        color: palette.textMuted,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    SizedBox(
                      height: 300,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: products.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: Insets.md),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            artisan: artisan,
                            width: 176,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProductDetailScreen(
                                    product: product,
                                    artisan: artisan,
                                    onBook: onBook,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Insets.x3l)),
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
                Expanded(
                  child: BelButton(
                    label: 'Reservar visita',
                    icon: Icons.event_available_outlined,
                    onPressed: onBook,
                  ),
                ),
                const SizedBox(width: Insets.md),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Material(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(Radii.sm + 2),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Escribir al artesano',
                      onPressed: whatsapp.isNotEmpty
                          ? () => ContactLinks.open(
                              context,
                              ContactLinks.whatsapp(
                                whatsapp,
                                message:
                                    'Hola, me interesa el trabajo de '
                                    '${artisan.name}.',
                              ),
                            )
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ContactScreen(
                                  presetMessage:
                                      'Hola, me interesa el trabajo de '
                                      '${artisan.name}.',
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.palette.textMuted),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: context.texts.bodyMedium)),
        ],
      ),
    );
  }
}

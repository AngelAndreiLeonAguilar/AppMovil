import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/app_tabs.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/section_header.dart';
import '../../data/demo_content.dart';
import '../../data/models.dart';
import '../artisans/artisan_detail_screen.dart';
import '../artisans/widgets/artisan_card.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/widgets/product_card.dart';
import '../contact/contact_screen.dart';
import '../map/widgets/bel_map.dart';
import '../account/account_screen.dart';
import '../../core/widgets/bel_logo.dart';

/// Pantalla de inicio: fotografía inmersiva, experiencias, piezas, artesanos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _HomeHero(onSelectTab: onSelectTab)),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.xxl,
              Insets.page,
              132,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Reveal(index: 0, child: _WelcomeBlock()),
                const SizedBox(height: Insets.x3l),
                Reveal(
                  index: 1,
                  child: _ExperiencesBlock(onSelectTab: onSelectTab),
                ),
                const SizedBox(height: Insets.x3l),
                Reveal(
                  index: 2,
                  child: _ProductsBlock(onSelectTab: onSelectTab),
                ),
                const SizedBox(height: Insets.x3l),
                Reveal(
                  index: 3,
                  child: _ArtisansBlock(onSelectTab: onSelectTab),
                ),
                const SizedBox(height: Insets.x3l),
                Reveal(index: 4, child: _MapBlock(onSelectTab: onSelectTab)),
                const SizedBox(height: Insets.x3l),
                Reveal(
                  index: 5,
                  child: _BookingBanner(onSelectTab: onSelectTab),
                ),
                const SizedBox(height: Insets.xl),
                const Reveal(index: 6, child: _ContactStrip()),
                const SizedBox(height: Insets.xxl),
                Center(
                  child: Text(
                    'Bel-Aaktun · Bécal, Campeche',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.textFaint,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Portada
// ---------------------------------------------------------------------------

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.74).clamp(500.0, 660.0);
    final titleSize = MediaQuery.sizeOf(context).width < 380 ? 38.0 : 44.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BelArtwork(
            imagePath: DemoContent.caves.first.imagePath,
            variant: ArtworkVariant.cave,
            seed: 3,
            scrim: true,
            label: 'Interior de una cueva artesanal en Bécal, Campeche',
          ),
          // Degradado superior para la barra de marca.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x8C21140E), Color(0x0021140E)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.sm,
                Insets.page,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BelLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BEL·AAKTUN',
                            style: context.texts.titleLarge?.copyWith(
                              color: AppColors.blancoCalido,
                              fontSize: 17,
                              letterSpacing: 3.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BÉCAL · CAMPECHE',
                            style: context.texts.labelSmall?.copyWith(
                              color: AppColors.blancoCalido.withValues(
                                alpha: 0.72,
                              ),
                              fontSize: 8.5,
                              letterSpacing: 2.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  BelIconButton(
                    icon: context.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    tooltip: context.isDark
                        ? 'Cambiar a modo claro'
                        : 'Cambiar a modo oscuro',
                    filled: true,
                    onPressed: () => ThemeScope.of(context).toggle(),
                  ),
                  const SizedBox(width: Insets.sm),
                  BelIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Contacto',
                    filled: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ContactScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  const AccountAvatarButton(),
                ],
              ),
            ),
          ),
          Positioned(
            left: Insets.page,
            right: Insets.page,
            bottom: Insets.x4l + 12,
            child: Reveal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARTESANÍA VIVA · JIPI JAPA',
                    style: context.eyebrowStyle.copyWith(
                      color: AppColors.doradoClaro,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'El arte de tejer\nla palma',
                    style: context.texts.displayLarge?.copyWith(
                      color: AppColors.blancoCalido,
                      fontSize: titleSize,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      'Sombreros que nacen en la penumbra de una cueva.',
                      style: context.quoteStyle(
                        size: 19,
                        color: AppColors.crema.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  Row(
                    children: [
                      Expanded(
                        child: BelButton(
                          label: 'Explorar',
                          icon: Icons.storefront_outlined,
                          onPressed: () => onSelectTab(AppTabs.catalog),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: BelButton(
                          label: 'Reservar',
                          icon: Icons.event_available_outlined,
                          variant: BelButtonVariant.light,
                          onPressed: () => onSelectTab(AppTabs.booking),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BÉCAL, CAMPECHE', style: context.eyebrowStyle),
        const SizedBox(height: Insets.md),
        Text(
          'Un pueblo que teje\nbajo la tierra',
          style: context.texts.headlineLarge,
        ),
        const SizedBox(height: Insets.md),
        Text(
          'En Bécal el oficio vive en las cuevas: la humedad mantiene flexible '
          'la palma y permite tejer el Jipi Japa durante horas. Bel-Aaktun '
          'reúne a los talleres que mantienen viva esa tradición.',
          style: context.texts.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: const [
            BelPill(label: 'Jipi Japa', icon: Icons.grass_outlined),
            BelPill(label: 'Cuevas', icon: Icons.terrain_outlined),
            BelPill(label: 'Visitas guiadas', icon: Icons.route_outlined),
          ],
        ),
      ],
    );
  }
}

class _ExperiencesBlock extends StatelessWidget {
  const _ExperiencesBlock({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    final experiences = context.app.activeServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'VIVE BÉCAL',
          title: 'Experiencias',
          subtitle: 'Recorridos cortos, grupos pequeños.',
          actionLabel: 'Reservar',
          onAction: () => onSelectTab(AppTabs.booking),
        ),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: experiences.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
            itemBuilder: (context, index) {
              final experience = experiences[index];
              return _ExperienceCard(
                experience: experience,
                index: index,
                onTap: () => onSelectTab(AppTabs.booking),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.experience,
    required this.index,
    required this.onTap,
  });

  final Experience experience;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: BelSurface(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: Radii.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 92,
              width: double.infinity,
              child: BelArtwork(
                imagePath: experience.coverImage,
                variant: ArtworkVariant.weave,
                seed: index + 1,
                label: experience.title,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.md,
                Insets.md,
                Insets.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: context.palette.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDuration(experience.durationMinutes),
                        style: context.texts.bodySmall,
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

class _ProductsBlock extends StatelessWidget {
  const _ProductsBlock({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    final featured = context.app.activeProducts.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'CATÁLOGO',
          title: 'Piezas destacadas',
          actionLabel: 'Ver todo',
          onAction: () => onSelectTab(AppTabs.catalog),
        ),
        SizedBox(
          height: 312,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
            itemBuilder: (context, index) {
              final product = featured[index];
              final artisan = context.app.artisanById(product.artisanId);
              return ProductCard(
                product: product,
                artisan: artisan,
                width: 186,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(
                        product: product,
                        artisan: artisan,
                        onBook: () {
                          Navigator.of(context).pop();
                          onSelectTab(AppTabs.booking);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtisansBlock extends StatelessWidget {
  const _ArtisansBlock({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'MANOS QUE TEJEN',
          title: 'Artesanos',
          actionLabel: 'Conocerlos',
          onAction: () => onSelectTab(AppTabs.artisans),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: context.app.artisans.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
            itemBuilder: (context, index) {
              final artisan = context.app.artisans[index];
              return ArtisanCard(
                artisan: artisan,
                heroTag: 'home-artisan-${artisan.id}',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtisanDetailScreen(
                        artisan: artisan,
                        heroTag: 'home-artisan-${artisan.id}',
                        onBook: () {
                          Navigator.of(context).pop();
                          onSelectTab(AppTabs.booking);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'UBICA LOS TALLERES',
          title: 'Mapa de cuevas',
          subtitle: 'Cinco puntos para empezar el recorrido.',
          actionLabel: 'Abrir',
          onAction: () => onSelectTab(AppTabs.map),
        ),
        BelSurface(
          onTap: () => onSelectTab(AppTabs.map),
          padding: const EdgeInsets.all(Insets.sm),
          radius: Radii.md,
          child: SizedBox(
            height: 168,
            child: BelMap(
              caves: DemoContent.caves,
              interactive: false,
              showRoute: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingBanner extends StatelessWidget {
  const _BookingBanner({required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.xl + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.terracotaOscuro, AppColors.terracota],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracota.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESERVA TU VISITA',
            style: context.eyebrowStyle.copyWith(
              color: AppColors.blancoCalido.withValues(alpha: 0.82),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Camina la cueva,\naprende el oficio.',
            style: context.texts.displaySmall?.copyWith(
              color: AppColors.blancoCalido,
              fontSize: 27,
              height: 1.12,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Cupo limitado por taller. Reserva con al menos un día de anticipación.',
            style: context.texts.bodyMedium?.copyWith(
              color: AppColors.blancoCalido.withValues(alpha: 0.88),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: BelButton(
              label: 'Reservar experiencia',
              icon: Icons.event_available_outlined,
              variant: BelButtonVariant.light,
              expand: false,
              compact: true,
              onPressed: () => onSelectTab(AppTabs.booking),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactStrip extends StatelessWidget {
  const _ContactStrip();

  @override
  Widget build(BuildContext context) {
    return BelSurface(
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 20, color: context.colors.secondary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConfig.address, style: context.texts.titleSmall),
                const SizedBox(height: 2),
                Text(AppConfig.schedule, style: context.texts.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          IconButton(
            tooltip: 'Contacto',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ContactScreen()),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            color: context.colors.primary,
          ),
        ],
      ),
    );
  }
}

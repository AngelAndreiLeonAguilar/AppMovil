import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/app_tabs.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/maps_links.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../data/demo_content.dart';
import '../../data/models.dart';
import 'widgets/bel_map.dart';

/// Mapa editorial de cuevas, talleres y punto de encuentro.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _selectedId = DemoContent.caves.first.id;

  CaveLocation get _selected =>
      DemoContent.caves.firstWhere((cave) => cave.id == _selectedId);

  IconData _iconFor(CaveKind kind) {
    switch (kind) {
      case CaveKind.cueva:
        return Icons.terrain_rounded;
      case CaveKind.taller:
        return Icons.handyman_rounded;
      case CaveKind.puntoDeEncuentro:
        return Icons.flag_rounded;
    }
  }

  String _labelFor(CaveKind kind) {
    switch (kind) {
      case CaveKind.cueva:
        return 'Cueva';
      case CaveKind.taller:
        return 'Taller';
      case CaveKind.puntoDeEncuentro:
        return 'Punto de encuentro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = _selected;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Ruta de las cuevas',
            title: 'Mapa',
            subtitle:
                'Cinco paradas entre cuevas, talleres y la plaza del pueblo.',
            actions: [
              if (AppConfig.showDemoBadges)
                const BelPill(label: 'Demo', icon: Icons.science_outlined),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                BelPill(
                  label: 'Cueva',
                  icon: Icons.terrain_rounded,
                  color: context.colors.primary,
                ),
                BelPill(
                  label: 'Taller',
                  icon: Icons.handyman_rounded,
                  color: context.colors.secondary,
                ),
                BelPill(
                  label: 'Punto de encuentro',
                  icon: Icons.flag_rounded,
                  color: palette.textMuted,
                ),
              ],
            ),
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
            child: SizedBox(
              height: 340,
              child: BelMap(
                caves: DemoContent.caves,
                selectedId: _selectedId,
                showLabels: true,
                onSelect: (cave) => setState(() => _selectedId = cave.id),
              ),
            ),
          ),
        ),

        if (AppConfig.showDemoBadges)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.sm,
                Insets.page,
                0,
              ),
              child: Text(
                'Mapa real de Bécal (OpenStreetMap). Las coordenadas de cada '
                'parada son aproximadas y se ajustarán cuando cada taller '
                'comparta su ubicación exacta.',
                style: context.texts.bodySmall?.copyWith(
                  color: palette.textFaint,
                  fontSize: 11.5,
                ),
              ),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _CaveCard(
                key: ValueKey(selected.id),
                cave: selected,
                icon: _iconFor(selected.kind),
                kindLabel: _labelFor(selected.kind),
                onBook: () => widget.onSelectTab(AppTabs.booking),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.x3l,
              Insets.page,
              Insets.sm,
            ),
            child: Text(
              'TODAS LAS PARADAS',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textMuted,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ),

        SliverList.builder(
          itemCount: DemoContent.caves.length,
          itemBuilder: (context, index) {
            final cave = DemoContent.caves[index];
            final isSelected = cave.id == _selectedId;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.page,
                Insets.xs,
                Insets.page,
                Insets.xs,
              ),
              child: _CaveTile(
                cave: cave,
                icon: _iconFor(cave.kind),
                selected: isSelected,
                onTap: () => setState(() => _selectedId = cave.id),
              ),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }
}

class _CaveCard extends StatelessWidget {
  const _CaveCard({
    super.key,
    required this.cave,
    required this.icon,
    required this.kindLabel,
    required this.onBook,
  });

  final CaveLocation cave;
  final IconData icon;
  final String kindLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final artists = cave.artisanIds
        .map(context.app.artisanById)
        .whereType<Artisan>()
        .toList();

    return BelSurface(
      padding: const EdgeInsets.all(Insets.md),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: BelArtwork(
                    imagePath: cave.imagePath,
                    variant: ArtworkVariant.cave,
                    seed: cave.id.hashCode,
                    label: cave.name,
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kindLabel.toUpperCase(),
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.primary,
                        letterSpacing: 1.8,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(cave.name, style: context.texts.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      cave.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (artists.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final artisan in artists)
                  BelPill(
                    label: artisan.name,
                    icon: Icons.person_outline_rounded,
                  ),
              ],
            ),
          ],
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: BelButton(
                  label: 'Reservar visita',
                  icon: Icons.event_available_outlined,
                  compact: true,
                  onPressed: onBook,
                ),
              ),
              const SizedBox(width: Insets.sm),
              SizedBox(
                width: 48,
                height: 44,
                child: Material(
                  color: context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(Radii.sm + 2),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    tooltip: 'Ver datos de la parada',
                    onPressed: () => _showDetails(context, cave, kindLabel),
                    icon: Icon(icon, size: 20),
                    color: context.palette.text,
                  ),
                ),
              ),
              if (cave.hasCoordinates) ...[
                const SizedBox(width: Insets.sm),
                SizedBox(
                  width: 48,
                  height: 44,
                  child: Material(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(Radii.sm + 2),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Cómo llegar',
                      onPressed: () => MapsLinks.openOrWarn(
                        context,
                        MapsLinks.directions(
                          cave.latitude!,
                          cave.longitude!,
                          label: cave.name,
                        ),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 21),
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CaveTile extends StatelessWidget {
  const _CaveTile({
    required this.cave,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final CaveLocation cave;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : palette.surfaceMuted,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? scheme.onPrimary : palette.textMuted,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cave.name, style: context.texts.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      cave.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: selected ? scheme.primary : palette.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showDetails(
  BuildContext context,
  CaveLocation cave,
  String kindLabel,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.page,
          Insets.sm,
          Insets.page,
          MediaQuery.viewInsetsOf(sheetContext).bottom + Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kindLabel.toUpperCase(), style: sheetContext.eyebrowStyle),
            const SizedBox(height: Insets.sm),
            Text(cave.name, style: sheetContext.texts.headlineMedium),
            const SizedBox(height: Insets.sm),
            Text(cave.description, style: sheetContext.texts.bodyMedium),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: palette.textMuted),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    AppConfig.address,
                    style: sheetContext.texts.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            if (cave.hasCoordinates) ...[
              Row(
                children: [
                  Expanded(
                    child: BelButton(
                      label: 'Cómo llegar',
                      icon: Icons.directions_rounded,
                      compact: true,
                      onPressed: () => MapsLinks.openOrWarn(
                        sheetContext,
                        MapsLinks.directions(
                          cave.latitude!,
                          cave.longitude!,
                          label: cave.name,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: BelButton(
                      label: 'Ver en el mapa',
                      icon: Icons.map_outlined,
                      variant: BelButtonVariant.outline,
                      compact: true,
                      onPressed: () => MapsLinks.openOrWarn(
                        sheetContext,
                        MapsLinks.point(
                          cave.latitude!,
                          cave.longitude!,
                          label: cave.name,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
            ],
            BelButton(
              label: 'Cerrar',
              variant: BelButtonVariant.outline,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
}

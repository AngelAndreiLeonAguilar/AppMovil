import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/bel_artwork.dart';
import '../../core/widgets/bel_button.dart';
import '../../core/widgets/bel_surface.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models.dart';
import 'widgets/product_form_sheet.dart';
import 'widgets/service_form_sheet.dart';
import '../../core/widgets/bel_empty_state.dart';

/// Catálogo del taller: piezas y experiencias editables.
class ArtisanCatalogScreen extends StatefulWidget {
  const ArtisanCatalogScreen({super.key});

  @override
  State<ArtisanCatalogScreen> createState() => _ArtisanCatalogScreenState();
}

class _ArtisanCatalogScreenState extends State<ArtisanCatalogScreen> {
  int _segment = 0;

  Future<void> _add(BuildContext context) async {
    if (_segment == 0) {
      await showProductForm(context);
    } else {
      await showServiceForm(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final palette = context.palette;
    final products = app.myProducts;
    final services = app.myServices;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Lo que ofreces',
            title: 'Mi catálogo',
            subtitle:
                '${products.length} '
                '${products.length == 1 ? 'pieza' : 'piezas'} · '
                '${services.length} '
                '${services.length == 1 ? 'experiencia' : 'experiencias'}',
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: [
                      BelFilterChip(
                        label: 'Piezas',
                        selected: _segment == 0,
                        onTap: () => setState(() => _segment = 0),
                      ),
                      BelFilterChip(
                        label: 'Experiencias',
                        selected: _segment == 1,
                        onTap: () => setState(() => _segment = 1),
                      ),
                    ],
                  ),
                ),
                BelButton(
                  label: 'Agregar',
                  icon: Icons.add_rounded,
                  compact: true,
                  expand: false,
                  onPressed: () => _add(context),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.md,
              Insets.page,
              0,
            ),
            child: Text(
              _segment == 0
                  ? 'Toca una pieza para editar fotos, precio o descripción. '
                        'Apaga el interruptor para ocultarla sin borrarla.'
                  : 'Toca una experiencia para editar precio, cupo o '
                        'anticipo. Si la desactivas, deja de aparecer al '
                        'reservar.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ),

        if (_segment == 0)
          if (products.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyCatalog(
                icon: Icons.inventory_2_outlined,
                title: 'Sin piezas publicadas',
                message:
                    'Agrega tu primera pieza para que aparezca en el catálogo '
                    'del pueblo.',
                actionLabel: 'Agregar pieza',
                onAction: () => showProductForm(context),
              ),
            )
          else
            SliverList.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.page,
                    Insets.sm,
                    Insets.page,
                    0,
                  ),
                  child: _ProductRow(
                    product: product,
                    onEdit: () => showProductForm(context, product: product),
                    onToggle: (value) =>
                        _toggleProduct(context, product, value),
                  ),
                );
              },
            )
        else if (services.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyCatalog(
              icon: Icons.event_note_outlined,
              title: 'Sin experiencias publicadas',
              message:
                  'Sin experiencias activas los turistas no pueden reservar '
                  'contigo.',
              actionLabel: 'Agregar experiencia',
              onAction: () => showServiceForm(context),
            ),
          )
        else
          SliverList.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  0,
                ),
                child: _ServiceRow(
                  service: service,
                  onEdit: () => showServiceForm(context, service: service),
                  onToggle: (value) => _toggleService(context, service, value),
                ),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 132)),
      ],
    );
  }

  Future<void> _toggleProduct(
    BuildContext context,
    Product product,
    bool value,
  ) async {
    final error = await context.app.setProductActive(product.id, value);
    if (!context.mounted) return;
    _report(context, error, value ? 'Pieza visible' : 'Pieza oculta');
  }

  Future<void> _toggleService(
    BuildContext context,
    Experience service,
    bool value,
  ) async {
    final error = await context.app.setServiceActive(service.id, value);
    if (!context.mounted) return;
    _report(
      context,
      error,
      value ? 'Experiencia visible' : 'Experiencia oculta',
    );
  }

  void _report(BuildContext context, String? error, String success) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? '$success.')));
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onToggle,
  });

  final Product product;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: product.isActive ? 1 : 0.55,
      child: BelSurface(
        onTap: onEdit,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            _Thumb(
              path: product.coverImage,
              variant: ArtworkVariant.craft,
              seed: product.id.hashCode,
              count: product.photos.length,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleSmall?.copyWith(
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (product.madeToOrder) ...[
                        const SizedBox(width: Insets.xs),
                        const BelPill(label: 'Encargo'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.category} · ${product.technique}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatPrice(product.price),
                        style: context.texts.titleSmall?.copyWith(
                          fontSize: 12,
                          color: context.colors.primary,
                        ),
                      ),
                      _StockChip(product: product),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Switch(
              value: product.isActive,
              onChanged: onToggle,
              activeThumbColor: context.colors.onPrimary,
              activeTrackColor: context.colors.primary,
              inactiveTrackColor: palette.surfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  final Experience service;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: service.isActive ? 1 : 0.55,
      child: BelSurface(
        onTap: onEdit,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            _Thumb(
              path: service.coverImage,
              variant: ArtworkVariant.cave,
              seed: service.id.hashCode,
              count: service.photos.length,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDuration(service.durationMinutes)} · hasta '
                    '${service.maxParticipants} personas · anticipo '
                    '${service.depositPercent}%',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatPrice(service.pricePerPerson)} por persona',
                    style: context.texts.titleSmall?.copyWith(
                      fontSize: 12,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Switch(
              value: service.isActive,
              onChanged: onToggle,
              activeThumbColor: context.colors.onPrimary,
              activeTrackColor: context.colors.primary,
              inactiveTrackColor: palette.surfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.page,
        Insets.xl,
        Insets.page,
        0,
      ),
      child: BelEmptyState(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        actionIcon: Icons.add_rounded,
        onAction: onAction,
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.path,
    required this.variant,
    required this.seed,
    required this.count,
  });

  final String? path;
  final ArtworkVariant variant;
  final int seed;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BelArtwork(
              imagePath: path,
              variant: variant,
              seed: seed,
              icon: count == 0 ? Icons.add_a_photo_outlined : null,
            ),
            if (count > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Existencias de una pieza; al tocarla se ajustan sin abrir el formulario.
class _StockChip extends StatelessWidget {
  const _StockChip({required this.product});

  final Product product;

  Future<void> _adjust(BuildContext context) async {
    final app = context.app;
    final messenger = ScaffoldMessenger.of(context);
    var value = product.stock ?? 0;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Existencias'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name, style: dialogContext.texts.bodyMedium),
              const SizedBox(height: Insets.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Menos',
                    onPressed: value > 0 ? () => setState(() => value--) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: dialogContext.texts.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Más',
                    onPressed: value < 999
                        ? () => setState(() => value++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Al aceptar un pedido se descuentan solas.',
                style: dialogContext.texts.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(value),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final error = await app.setProductStock(product.id, result);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error ?? 'Existencias actualizadas: $result.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (product.madeToOrder) {
      return Text(
        product.productionDays == null
            ? 'Por encargo'
            : 'Por encargo · ${product.productionDays} días',
        style: context.texts.labelSmall?.copyWith(color: palette.textMuted),
      );
    }
    if (product.stock == null) {
      return Text(
        'Sin conteo',
        style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
      );
    }
    final stock = product.stock!;
    final color = stock <= 0
        ? context.colors.error
        : stock <= 2
        ? context.colors.secondary
        : palette.textMuted;
    return InkWell(
      onTap: () => _adjust(context),
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          stock <= 0 ? 'Agotada · ajustar' : 'Quedan $stock · ajustar',
          style: context.texts.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/navigation/app_tabs.dart';
import '../../core/state/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_tag.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/reveal.dart';
import '../../data/demo_content.dart';
import '../../data/models.dart';
import 'product_detail_screen.dart';
import 'widgets/product_card.dart';
import '../orders/cart_screen.dart';

/// Catálogo de piezas artesanales con búsqueda y filtros por categoría.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.onSelectTab});

  final SelectTab onSelectTab;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = DemoContent.categories.first;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Categorías visibles: las base más las que agreguen los talleres.
  List<String> get _categories {
    final set = <String>{...DemoContent.categories};
    for (final product in context.app.activeProducts) {
      set.add(product.category);
    }
    return set.toList();
  }

  List<Product> get _results {
    final products = context.app.activeProducts;
    final byCategory = _category == DemoContent.categories.first
        ? products
        : [
            for (final product in products)
              if (product.category == _category) product,
          ];
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return byCategory;

    return byCategory.where((product) {
      final artisan = context.app.artisanById(product.artisanId);
      return product.name.toLowerCase().contains(query) ||
          product.technique.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          (artisan?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          product: product,
          artisan: context.app.artisanById(product.artisanId),
          onBook: () {
            Navigator.of(context).pop();
            widget.onSelectTab(AppTabs.booking);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final categories = _categories;
    if (!categories.contains(_category)) {
      _category = categories.first;
    }
    final results = _results;
    final columns = MediaQuery.sizeOf(context).width >= 720 ? 3 : 2;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            eyebrow: 'Hecho a mano',
            title: 'Catálogo',
            subtitle: 'Cada pieza sale de una cueva y lleva el nombre de quien la tejió.',
            actions: const [CartButton()],
          ),
        ),

        // Buscador
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: palette.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: Row(
                children: [
                  const SizedBox(width: Insets.xs),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: palette.textMuted,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      style: context.texts.bodyMedium,
                      cursorColor: context.colors.primary,
                      decoration: InputDecoration(
                        hintText: 'Buscar pieza, técnica o artesano',
                        hintStyle: context.texts.bodyMedium?.copyWith(
                          color: palette.textFaint,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: palette.textMuted,
                    )
                  else
                    const SizedBox(width: Insets.sm),
                ],
              ),
            ),
          ),
        ),

        // Filtros
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Center(
                    child: BelFilterChip(
                      label: category,
                      selected: category == _category,
                      onTap: () => setState(() => _category = category),
                    ),
                  );
                },
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
              Insets.md,
            ),
            child: Text(
              results.length == 1 ? '1 pieza' : '${results.length} piezas',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textMuted,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),

        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              onReset: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _category = DemoContent.categories.first;
                });
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              0,
              Insets.page,
              132,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: Insets.md,
                mainAxisSpacing: Insets.xl,
                mainAxisExtent: 320,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final product = results[index];
                return Reveal(
                  index: index % 6,
                  child: ProductCard(
                    product: product,
                    artisan: context.app.artisanById(product.artisanId),
                    onTap: () => _openProduct(product),
                  ),
                );
              }, childCount: results.length),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.x3l,
        Insets.x3l,
        Insets.x3l,
        132,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: context.palette.textFaint,
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'Sin piezas para esa búsqueda',
            textAlign: TextAlign.center,
            style: context.texts.titleLarge,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Prueba con otra categoría o revisa la ortografía del artesano.',
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium,
          ),
          const SizedBox(height: Insets.xl),
          SizedBox(
            width: 200,
            child: OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primary,
                side: BorderSide(color: context.palette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                minimumSize: const Size.fromHeight(Insets.touch),
              ),
              child: const Text('Ver todo el catálogo'),
            ),
          ),
        ],
      ),
    );
  }
}

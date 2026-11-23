import 'package:flutter/material.dart';

import '../../core/navigation/app_tabs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_bottom_bar.dart';
import '../../core/widgets/keep_alive_page.dart';
import '../artisans/artisans_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../catalog/catalog_screen.dart';
import '../home/home_screen.dart';
import '../map/map_screen.dart';

/// Contenedor principal del turista: navegación inferior + cinco secciones.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final PageController _pageController = PageController(
    initialPage: AppTabs.home,
  );

  int _index = AppTabs.home;

  static const _items = <BelTabItem>[
    BelTabItem(Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    BelTabItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Catálogo'),
    BelTabItem(Icons.map_outlined, Icons.map_rounded, 'Mapa'),
    BelTabItem(Icons.groups_outlined, Icons.groups_rounded, 'Artesanos'),
    BelTabItem(
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Actividad',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Cambia de pestaña desde la barra inferior o desde un botón de una pantalla.
  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (index == _index) return;
                setState(() => _index = index);
              },
              physics: const PageScrollPhysics(),
              children: [
                KeepAlivePage(child: HomeScreen(onSelectTab: _select)),
                KeepAlivePage(child: CatalogScreen(onSelectTab: _select)),
                KeepAlivePage(child: MapScreen(onSelectTab: _select)),
                KeepAlivePage(child: ArtisansScreen(onSelectTab: _select)),
                const KeepAlivePage(child: MyBookingsScreen()),
              ],
            ),
          ),
          // Desvanecido inferior para que el contenido pase con elegancia
          // por debajo de la barra flotante.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.background.withValues(alpha: 0),
                      palette.background.withValues(alpha: 0.86),
                      palette.background,
                    ],
                    stops: const [0, 0.62, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BelBottomBar(
        items: _items,
        index: _index,
        onSelect: _select,
      ),
    );
  }
}

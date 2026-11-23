import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/bel_bottom_bar.dart';
import '../../core/widgets/keep_alive_page.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';

/// Contenedor del módulo del artesano: panel, agenda, catálogo y ganancias.
class ArtisanShell extends StatefulWidget {
  const ArtisanShell({super.key});

  @override
  State<ArtisanShell> createState() => _ArtisanShellState();
}

class _ArtisanShellState extends State<ArtisanShell> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const _items = <BelTabItem>[
    BelTabItem(
      Icons.dashboard_outlined,
      Icons.dashboard_rounded,
      'Panel',
    ),
    BelTabItem(
      Icons.event_note_outlined,
      Icons.event_note_rounded,
      'Pedidos',
    ),
    BelTabItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Catálogo'),
    BelTabItem(
      Icons.insights_outlined,
      Icons.insights_rounded,
      'Ingresos',
    ),
    BelTabItem(
      Icons.storefront_outlined,
      Icons.storefront_rounded,
      'Perfil',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                KeepAlivePage(
                  child: ArtisanDashboardScreen(onSelectTab: _select),
                ),
                const KeepAlivePage(child: ArtisanReservationsScreen()),
                const KeepAlivePage(child: ArtisanCatalogScreen()),
                const KeepAlivePage(child: ArtisanEarningsScreen()),
                const KeepAlivePage(child: ArtisanProfileScreen()),
              ],
            ),
          ),
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

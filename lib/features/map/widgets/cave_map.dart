import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';

/// Mapa ilustrado de las cuevas y talleres de Bécal.
///
/// Las posiciones vienen de [CaveLocation.mapX] / [CaveLocation.mapY]
/// (normalizadas 0–1). Es un mapa editorial, no un mapa geográfico: cuando el
/// backend entregue latitud/longitud puedes sustituir este widget por tu
/// proveedor de mapas sin tocar el resto de la pantalla.
class CaveMap extends StatelessWidget {
  const CaveMap({
    super.key,
    required this.caves,
    this.selectedId,
    this.onSelect,
    this.showLabels = false,
  });

  final List<CaveLocation> caves;
  final String? selectedId;
  final ValueChanged<CaveLocation>? onSelect;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapPainter(
                    surface: palette.surfaceMuted,
                    ink: palette.border,
                    water: context.colors.secondary.withValues(alpha: 0.22),
                    foliage: const Color(0xFF5C6B4A).withValues(alpha: 0.18),
                  ),
                ),
              ),
              for (final cave in caves)
                Positioned(
                  left: (cave.mapX * width - 20).clamp(4.0, width - 44),
                  top: (cave.mapY * height - 20).clamp(
                    4.0,
                    height - (showLabels ? 46 : 44),
                  ),
                  child: _CaveMarker(
                    cave: cave,
                    selected: cave.id == selectedId,
                    showLabel: showLabels,
                    onTap: onSelect == null ? null : () => onSelect!(cave),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CaveMarker extends StatelessWidget {
  const _CaveMarker({
    required this.cave,
    required this.selected,
    required this.showLabel,
    this.onTap,
  });

  final CaveLocation cave;
  final bool selected;
  final bool showLabel;
  final VoidCallback? onTap;

  IconData get _icon {
    switch (cave.kind) {
      case CaveKind.cueva:
        return Icons.terrain_rounded;
      case CaveKind.taller:
        return Icons.handyman_rounded;
      case CaveKind.puntoDeEncuentro:
        return Icons.flag_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final palette = context.palette;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: cave.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: selected ? 42 : 34,
              height: selected ? 42 : 34,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : palette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : palette.border,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _icon,
                size: selected ? 20 : 16,
                color: selected ? scheme.onPrimary : scheme.primary,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Container(
                constraints: const BoxConstraints(maxWidth: 92),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                child: Text(
                  cave.name.replaceFirst('Cueva ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.2,
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.surface,
    required this.ink,
    required this.water,
    required this.foliage,
  });

  final Color surface;
  final Color ink;
  final Color water;
  final Color foliage;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = surface);

    // Manchas de vegetación.
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.1,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.4,
      ),
      Paint()..color = foliage,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.6,
        size.height * 0.55,
        size.width * 0.5,
        size.height * 0.5,
      ),
      Paint()..color = foliage,
    );

    // Caminos: curvas suaves que cruzan el pueblo.
    final roads = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.55);

    final roadsInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = surface;

    final paths = <Path>[
      Path()
        ..moveTo(-10, size.height * 0.78)
        ..cubicTo(
          size.width * 0.28,
          size.height * 0.66,
          size.width * 0.42,
          size.height * 0.86,
          size.width * 0.72,
          size.height * 0.62,
        )
        ..cubicTo(
          size.width * 0.84,
          size.height * 0.52,
          size.width * 0.9,
          size.height * 0.34,
          size.width + 10,
          size.height * 0.24,
        ),
      Path()
        ..moveTo(size.width * 0.3, -10)
        ..cubicTo(
          size.width * 0.34,
          size.height * 0.3,
          size.width * 0.22,
          size.height * 0.5,
          size.width * 0.38,
          size.height + 10,
        ),
      Path()
        ..moveTo(size.width * 0.66, size.height + 10)
        ..cubicTo(
          size.width * 0.6,
          size.height * 0.7,
          size.width * 0.78,
          size.height * 0.5,
          size.width * 0.7,
          size.height * 0.02,
        ),
    ];

    for (final path in paths) {
      canvas.drawPath(path, roads);
      canvas.drawPath(path, roadsInner);
    }

    // Cenote / ojo de agua.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.84, size.height * 0.86),
        width: size.width * 0.26,
        height: size.height * 0.24,
      ),
      Paint()..color = water,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.84, size.height * 0.86),
        width: size.width * 0.26,
        height: size.height * 0.24,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = water.withValues(alpha: 0.9),
    );

    // Trama fina, como papel de plano.
    final hatch = Paint()
      ..color = ink.withValues(alpha: 0.22)
      ..strokeWidth = 0.7;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hatch);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) {
    return old.surface != surface || old.ink != ink;
  }
}

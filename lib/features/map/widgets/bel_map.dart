import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import 'cave_map.dart';

/// Mapa geográfico real de las paradas de Bel-Aaktun.
///
/// Dibuja las cuevas, talleres y el punto de encuentro sobre un mapa de
/// teselas reales (por defecto OpenStreetMap, sin API key) con pellizco para
/// zoom, arrastre y botones de zoom / encuadre.
///
/// Si alguna parada no tiene coordenadas ([CaveLocation.hasCoordinates]) se
/// conserva el mapa ilustrado ([CaveMap]) como respaldo, de modo que la
/// pantalla nunca queda vacía.
class BelMap extends StatefulWidget {
  const BelMap({
    super.key,
    required this.caves,
    this.selectedId,
    this.onSelect,
    this.showLabels = false,
    this.interactive = true,
    this.showRoute = true,
  });

  final List<CaveLocation> caves;
  final String? selectedId;
  final ValueChanged<CaveLocation>? onSelect;

  /// Muestra el nombre de la parada seleccionada sobre su pin.
  final bool showLabels;

  /// Con `false` el mapa no captura gestos (útil dentro de un scroll).
  final bool interactive;

  /// Traza la ruta entre las paradas en el orden de la lista.
  final bool showRoute;

  @override
  State<BelMap> createState() => _BelMapState();
}

class _BelMapState extends State<BelMap> {
  final MapController _controller = MapController();
  bool _mapReady = false;

  List<CaveLocation> get _located => [
    for (final cave in widget.caves)
      if (cave.hasCoordinates) cave,
  ];

  LatLng _pointOf(CaveLocation cave) =>
      LatLng(cave.latitude!, cave.longitude!);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady || !widget.interactive) return;
    if (widget.selectedId == null || widget.selectedId == oldWidget.selectedId) {
      return;
    }
    for (final cave in _located) {
      if (cave.id == widget.selectedId) {
        _controller.move(
          _pointOf(cave),
          math.max(_controller.camera.zoom, 16),
        );
        return;
      }
    }
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _controller.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0);
    _controller.move(camera.center, zoom);
  }

  void _fitAll() {
    if (!_mapReady) return;
    final points = _located.map(_pointOf).toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.first, 16);
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        // Margen generoso arriba: el pin seleccionado crece hacia arriba con
        // su etiqueta y no debe quedar fuera del encuadre.
        padding: const EdgeInsets.fromLTRB(56, 96, 56, 48),
        maxZoom: 16,
      ),
    );
  }

  /// Orden de visita sugerido: recorre las paradas en sentido circular desde el
  /// punto de encuentro, de modo que la línea de la ruta no se cruce consigo
  /// misma.
  List<LatLng> get _route {
    final points = _located.map(_pointOf).toList();
    if (points.length < 3) return points;

    var latSum = 0.0;
    var lngSum = 0.0;
    for (final point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    final latMean = latSum / points.length;
    final lngMean = lngSum / points.length;

    double angleOf(LatLng point) => math.atan2(
      point.latitude - latMean,
      (point.longitude - lngMean) * math.cos(latMean * math.pi / 180),
    );

    final sorted = [...points]..sort((a, b) => angleOf(a).compareTo(angleOf(b)));

    // La ruta termina en el punto de encuentro: se empieza en la parada que le
    // sigue en el recorrido circular.
    var startIndex = 0;
    for (final cave in _located) {
      if (cave.kind == CaveKind.puntoDeEncuentro) {
        final index = sorted.indexWhere(
          (point) =>
              point.latitude == cave.latitude &&
              point.longitude == cave.longitude,
        );
        if (index >= 0) startIndex = (index + 1) % sorted.length;
        break;
      }
    }

    return [
      ...sorted.sublist(startIndex),
      ...sorted.sublist(0, startIndex),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    final located = _located;

    if (located.isEmpty) {
      // Sin coordenadas todavía: se conserva el mapa editorial ilustrado.
      return CaveMap(
        caves: widget.caves,
        selectedId: widget.selectedId,
        onSelect: widget.onSelect,
        showLabels: widget.showLabels,
      );
    }

    final points = located.map(_pointOf).toList();
    final selectedCave = located.where((cave) => cave.id == widget.selectedId);
    final ordered = [
      for (final cave in located)
        if (cave.id != widget.selectedId) cave,
      if (selectedCave.isNotEmpty) selectedCave.first,
    ];

    final tiles = TileLayer(
      urlTemplate: AppConfig.mapTileUrl,
      userAgentPackageName: AppConfig.packageName,
      maxNativeZoom: 19,
      tileProvider: NetworkTileProvider(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.interactive,
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: const LatLng(
                    AppConfig.mapCenterLat,
                    AppConfig.mapCenterLng,
                  ),
                  initialZoom: AppConfig.mapInitialZoom,
                  initialCameraFit: points.length > 1
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.fromLTRB(56, 96, 56, 48),
                          maxZoom: 15.5,
                        )
                      : null,
                  minZoom: 3,
                  maxZoom: 19,
                  backgroundColor: palette.surfaceMuted,
                  keepAlive: true,
                  interactionOptions: InteractionOptions(
                    flags: widget.interactive
                        ? InteractiveFlag.all & ~InteractiveFlag.rotate
                        : InteractiveFlag.none,
                  ),
                  onMapReady: () {
                    if (mounted) setState(() => _mapReady = true);
                  },
                ),
                children: [
                  // El tema es oscuro: se tiñe el mapa para que no deslumbre.
                  if (context.isDark)
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        AppColors.marronOscuro.withValues(alpha: 0.42),
                        BlendMode.srcOver,
                      ),
                      child: tiles,
                    )
                  else
                    tiles,

                  if (widget.showRoute && points.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route,
                          strokeWidth: 3.5,
                          color: scheme.primary.withValues(alpha: 0.55),
                        ),
                      ],
                    ),

                  MarkerLayer(
                    markers: [
                      for (final cave in ordered)
                        Marker(
                          point: _pointOf(cave),
                          width: cave.id == widget.selectedId ? 176 : 46,
                          height: cave.id == widget.selectedId ? 96 : 54,
                          alignment: Alignment.topCenter,
                          child: _MapPin(
                            cave: cave,
                            selected: cave.id == widget.selectedId,
                            showLabel: widget.showLabels,
                            onTap: widget.onSelect == null
                                ? null
                                : () => widget.onSelect!(cave),
                          ),
                        ),
                    ],
                  ),

                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(Radii.xs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          AppConfig.mapAttribution,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 9,
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.interactive)
            Positioned(
              right: 10,
              top: 10,
              child: _MapControls(
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onFit: _fitAll,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
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
    final size = selected ? 44.0 : 34.0;
    final fill = selected ? scheme.primary : palette.surface;
    final tint = selected ? scheme.onPrimary : scheme.primary;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: cave.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (selected && showLabel) ...[
              Container(
                constraints: const BoxConstraints(maxWidth: 168),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  cave.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fill,
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
              child: Icon(_icon, size: selected ? 21 : 17, color: tint),
            ),
            CustomPaint(
              size: Size(size * 0.34, 9),
              painter: _PinTipPainter(fill),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  const _PinTipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlButton(icon: Icons.add_rounded, tooltip: 'Acercar', onTap: onZoomIn),
        const SizedBox(height: Insets.xs),
        _ControlButton(
          icon: Icons.remove_rounded,
          tooltip: 'Alejar',
          onTap: onZoomOut,
        ),
        const SizedBox(height: Insets.xs),
        _ControlButton(
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Ver todas las paradas',
          onTap: onFit,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(Radii.xs),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.xs),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: palette.text),
          ),
        ),
      ),
    );
  }
}

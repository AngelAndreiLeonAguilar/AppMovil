import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bel_palette.dart';

/// Tipo de marcador visual dibujado.
enum ArtworkVariant {
  /// Arco de cueva con luz cálida al fondo.
  cave,

  /// Círculos concéntricos: tejido del sombrero de Jipi Japa.
  craft,

  /// Silueta de retrato para fichas de artesanos.
  portrait,

  /// Solo la trama del tejido.
  weave,
}

final Map<String, ImageProvider> _memoryCache = {};

/// Convierte una ruta de imagen de la app en un [ImageProvider].
///
/// Acepta assets (`assets/...`), URLs, data URIs (web) y archivos locales
/// guardados por `PhotoService`.
ImageProvider? belImageProvider(String path) {
  if (path.isEmpty) return null;
  if (path.startsWith('assets/')) return AssetImage(path);
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('data:')) {
    return _memoryCache.putIfAbsent(path, () {
      final comma = path.indexOf(',');
      return MemoryImage(base64Decode(path.substring(comma + 1)));
    });
  }
  if (kIsWeb) return null;
  return FileImage(File(path));
}

/// Superficie visual de Bel-Aaktun.
///
/// Muestra la fotografía indicada en [imagePath] o, mientras no exista una
/// imagen real, un marcador dibujado en código con la paleta de la marca.
/// Ocupa todo el espacio que le dé su padre, así que debe ir dentro de un
/// `SizedBox`, `AspectRatio`, `Expanded` o similar.
class BelArtwork extends StatelessWidget {
  const BelArtwork({
    super.key,
    this.imagePath,
    this.variant = ArtworkVariant.cave,
    this.seed = 0,
    this.scrim = false,
    this.label,
    this.icon,
    this.overlayAlignment = Alignment.center,
  });

  /// Ruta de un asset real, por ejemplo `assets/images/cueva.jpg`.
  final String? imagePath;
  final ArtworkVariant variant;

  /// Varía ligeramente la composición para que dos tarjetas no se repitan.
  final int seed;

  /// Oscurece la parte inferior para colocar texto encima.
  final bool scrim;

  /// Descripción accesible del contenido.
  final String? label;

  /// Icono tenue al centro del marcador (solo sin fotografía).
  final IconData? icon;

  final Alignment overlayAlignment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasImage = imagePath != null && imagePath!.isNotEmpty;

    final provider = hasImage ? belImageProvider(imagePath!) : null;
    Widget artwork = provider != null
        ? Image(
            image: provider,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) =>
                _Painted(variant: variant, seed: seed, palette: palette),
          )
        : _Painted(variant: variant, seed: seed, palette: palette);

    if (!hasImage && icon != null) {
      artwork = Stack(
        fit: StackFit.expand,
        children: [
          artwork,
          Align(
            alignment: overlayAlignment,
            child: Icon(
              icon,
              size: 34,
              color: palette.artworkVeil.withValues(alpha: 0.22),
            ),
          ),
        ],
      );
    }

    // Recorta siempre: el pintor dibuja formas que pueden rozar el borde.
    artwork = ClipRect(child: artwork);

    if (scrim) {
      artwork = Stack(
        fit: StackFit.expand,
        children: [
          artwork,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0021140E),
                  Color(0x1A21140E),
                  Color(0xB321140E),
                  Color(0xF221140E),
                ],
                stops: [0.0, 0.42, 0.78, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    if (label == null) return artwork;

    return Semantics(label: label, image: true, child: artwork);
  }
}

class _Painted extends StatelessWidget {
  const _Painted({
    required this.variant,
    required this.seed,
    required this.palette,
  });

  final ArtworkVariant variant;
  final int seed;
  final BelPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArtworkPainter(
        variant: variant,
        seed: seed,
        base: palette.artworkBase,
        glow: palette.artworkGlow,
      ),
      isComplex: true,
      willChange: false,
    );
  }
}

class _ArtworkPainter extends CustomPainter {
  _ArtworkPainter({
    required this.variant,
    required this.seed,
    required this.base,
    required this.glow,
  });

  final ArtworkVariant variant;
  final int seed;
  final Color base;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final accent = Color.lerp(glow, const Color(0xFFC99A32), 0.65)!;

    // Fondo: marrón profundo con un sesgo cálido según la semilla.
    final shift = (seed % 5) / 10.0;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + shift, -1),
          end: Alignment(1, 1 - shift),
          colors: [
            Color.lerp(base, glow, 0.32)!,
            base,
            Color.lerp(base, const Color(0xFF140B07), 0.35)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Luz cálida desde el interior de la cueva.
    final lightCenter = Offset(
      size.width * (0.42 + (seed % 3) * 0.08),
      size.height * (variant == ArtworkVariant.portrait ? 0.42 : 0.82),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                glow.withValues(alpha: 0.62),
                glow.withValues(alpha: 0.16),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: lightCenter,
                radius: size.longestSide * 0.75,
              ),
            ),
    );

    _drawWeave(canvas, size, accent);

    switch (variant) {
      case ArtworkVariant.cave:
        _drawCave(canvas, size, accent);
      case ArtworkVariant.craft:
        _drawCraft(canvas, size, accent);
      case ArtworkVariant.portrait:
        _drawPortrait(canvas, size, accent);
      case ArtworkVariant.weave:
        break;
    }

    // Viñeta para dar profundidad fotográfica.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, base.withValues(alpha: 0.55)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  void _drawWeave(Canvas canvas, Size size, Color accent) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.07)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    const spacing = 13.0;
    final diagonal = size.width + size.height;

    for (double d = -size.height; d < diagonal; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
    for (double d = 0; d < diagonal; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d - size.height, size.height),
        paint,
      );
    }
  }

  void _drawCave(Canvas canvas, Size size, Color accent) {
    final archWidth = size.width * (0.66 + (seed % 3) * 0.05);
    final archHeight = size.height * (0.80 + (seed % 2) * 0.06);
    final left = (size.width - archWidth) / 2;
    final bottom = size.height + 1;
    final top = bottom - archHeight;
    final radius = archWidth / 2;

    final arch = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + radius)
      ..arcToPoint(
        Offset(left + archWidth, top + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(left + archWidth, bottom)
      ..close();

    canvas.drawPath(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            base.withValues(alpha: 0.55),
            const Color(0xFF140B07).withValues(alpha: 0.94),
          ],
        ).createShader(arch.getBounds().inflate(1)),
    );

    // Borde iluminado del arco.
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.16),
    );

    // Hebras de palma colgando del techo.
    final strand = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 7; i++) {
      final x = left + archWidth * (0.12 + i * 0.12);
      final drop = archHeight * (0.10 + (i % 3) * 0.045);
      final path = Path()
        ..moveTo(x, top + radius * 0.35)
        ..quadraticBezierTo(
          x + (i.isEven ? 6 : -6),
          top + radius * 0.35 + drop * 0.6,
          x + (i.isEven ? 2 : -2),
          top + radius * 0.35 + drop,
        );
      canvas.drawPath(path, strand);
    }
  }

  void _drawCraft(Canvas canvas, Size size, Color accent) {
    final center = Offset(size.width * 0.5, size.height * 0.56);
    final maxRadius = math.min(size.width, size.height) * 0.42;

    // Ala del sombrero.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, maxRadius * 0.62),
        width: maxRadius * 2.5,
        height: maxRadius * 0.9,
      ),
      Paint()
        ..color = const Color(0xFF140B07).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill,
    );

    for (var i = 6; i >= 1; i--) {
      final radius = maxRadius * (i / 6);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = accent.withValues(alpha: 0.10 + 0.07 * (6 - i)),
      );
    }

    // Copa del sombrero.
    canvas.drawCircle(
      center,
      maxRadius * 0.62,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Color.lerp(base, glow, 0.45)!,
                base.withValues(alpha: 0.9),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: maxRadius * 0.62),
            ),
    );

    canvas.drawCircle(
      center,
      maxRadius * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.4),
    );
  }

  void _drawPortrait(Canvas canvas, Size size, Color accent) {
    final center = Offset(size.width * 0.5, size.height * 0.44);
    final radius = math.min(size.width, size.height) * 0.22;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(base, glow, 0.55)!, base.withValues(alpha: 0.85)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final shoulders = Path()
      ..moveTo(size.width * 0.16, size.height)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.66,
        size.width * 0.5,
        size.height * 0.64,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.66,
        size.width * 0.84,
        size.height,
      )
      ..close();

    canvas.drawPath(
      shoulders,
      Paint()..color = const Color(0xFF140B07).withValues(alpha: 0.5),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = accent.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter old) {
    return old.variant != variant ||
        old.seed != seed ||
        old.base != base ||
        old.glow != glow;
  }
}

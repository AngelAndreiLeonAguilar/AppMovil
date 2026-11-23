import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'bel_artwork.dart';

/// Galería deslizable con indicador de puntos.
///
/// Con una sola foto (o ninguna) se comporta como un [BelArtwork] normal.
/// Al tocarla se abre en pantalla completa con zoom.
class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    super.key,
    required this.photos,
    this.variant = ArtworkVariant.craft,
    this.seed = 0,
    this.scrim = false,
    this.label,
  });

  final List<String> photos;
  final ArtworkVariant variant;
  final int seed;
  final bool scrim;
  final String? label;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _page = 0;

  void _openViewer(int index) {
    if (widget.photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _PhotoViewer(photos: widget.photos, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.length <= 1) {
      return GestureDetector(
        onTap: photos.isEmpty ? null : () => _openViewer(0),
        child: BelArtwork(
          imagePath: photos.isEmpty ? null : photos.first,
          variant: widget.variant,
          seed: widget.seed,
          scrim: widget.scrim,
          label: widget.label,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _openViewer(index),
            child: BelArtwork(
              imagePath: photos[index],
              variant: widget.variant,
              seed: widget.seed + index,
              scrim: widget.scrim,
              label: widget.label,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: Insets.lg,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < photos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == _page ? 0.95 : 0.55,
                      ),
                      borderRadius: BorderRadius.circular(4),
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

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_page + 1} de ${widget.photos.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) {
          final provider = belImageProvider(widget.photos[index]);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: provider == null
                  ? const Icon(Icons.broken_image_outlined, color: Colors.white)
                  : Image(image: provider, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

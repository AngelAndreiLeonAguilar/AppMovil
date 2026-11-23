import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/photo_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'bel_artwork.dart';

/// Pregunta de dónde sacar la foto. Devuelve `null` si se cancela.
Future<ImageSource?> showPhotoSourceSheet(
  BuildContext context, {
  bool allowRemove = false,
  VoidCallback? onRemove,
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          0,
          Insets.page,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar foto', style: sheetContext.texts.titleLarge),
            const SizedBox(height: Insets.xs),
            Text(
              'Usa luz natural y un fondo sencillo: la pieza se luce más.',
              style: sheetContext.texts.bodySmall?.copyWith(
                color: sheetContext.palette.textMuted,
              ),
            ),
            const SizedBox(height: Insets.md),
            _SourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Tomar foto con la cámara',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Elegir de mi galería',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            if (allowRemove)
              _SourceTile(
                icon: Icons.delete_outline_rounded,
                label: 'Quitar foto',
                destructive: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRemove?.call();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colors.error : context.palette.text;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: context.texts.bodyLarge?.copyWith(color: color),
      ),
      onTap: onTap,
    );
  }
}

/// Elige una foto mostrando avisos amables si algo falla (permisos, etc.).
Future<String?> pickSinglePhoto(
  BuildContext context, {
  bool allowRemove = false,
  VoidCallback? onRemove,
}) async {
  final source = await showPhotoSourceSheet(
    context,
    allowRemove: allowRemove,
    onRemove: onRemove,
  );
  if (source == null) return null;
  try {
    return await PhotoService.pick(source);
  } on PlatformException catch (error) {
    if (context.mounted) _warn(context, error);
    return null;
  } catch (_) {
    if (context.mounted) {
      _snack(context, 'No se pudo cargar la foto. Intenta con otra.');
    }
    return null;
  }
}

void _warn(BuildContext context, PlatformException error) {
  final denied =
      error.code.contains('denied') || error.code.contains('access');
  _snack(
    context,
    denied
        ? 'Bel-Aaktun no tiene permiso para usar la cámara o tus fotos. '
              'Actívalo en Ajustes del teléfono.'
        : 'No se pudo abrir la cámara o la galería.',
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Editor de galería: agregar, quitar y elegir la foto de portada.
class PhotoGalleryEditor extends StatelessWidget {
  const PhotoGalleryEditor({
    super.key,
    required this.photos,
    required this.onChanged,
    this.max = 6,
    this.variant = ArtworkVariant.craft,
    this.helper,
  });

  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int max;
  final ArtworkVariant variant;
  final String? helper;

  Future<void> _add(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    try {
      final remaining = max - photos.length;
      final added = source == ImageSource.gallery
          ? await PhotoService.pickMany(limit: remaining)
          : [?await PhotoService.pick(source)];
      if (added.isEmpty) return;
      onChanged([...photos, ...added.take(remaining)]);
    } on PlatformException catch (error) {
      if (context.mounted) _warn(context, error);
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'No se pudo cargar la foto. Intenta con otra.');
      }
    }
  }

  Future<void> _options(BuildContext context, int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index != 0)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Usar como portada'),
                onTap: () => Navigator.of(sheetContext).pop('cover'),
              ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_back_rounded),
                title: const Text('Mover a la izquierda'),
                onTap: () => Navigator.of(sheetContext).pop('left'),
              ),
            if (index < photos.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: const Text('Mover a la derecha'),
                onTap: () => Navigator.of(sheetContext).pop('right'),
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: sheetContext.colors.error,
              ),
              title: Text(
                'Quitar foto',
                style: TextStyle(color: sheetContext.colors.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final next = [...photos];
    switch (action) {
      case 'cover':
        next.insert(0, next.removeAt(index));
      case 'left':
        next.insert(index - 1, next.removeAt(index));
      case 'right':
        next.insert(index + 1, next.removeAt(index));
      case 'remove':
        next.removeAt(index);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canAdd = photos.length < max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'FOTOS',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textMuted,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(),
            Text(
              '${photos.length} de $max',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (canAdd)
                _AddTile(
                  onTap: () => _add(context),
                  first: photos.isEmpty,
                ),
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: Insets.sm),
                  child: _PhotoTile(
                    path: photos[i],
                    isCover: i == 0,
                    variant: variant,
                    onTap: () => _options(context, i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          helper ??
              'La primera foto es la portada. Toca una foto para moverla o '
                  'quitarla.',
          style: context.texts.bodySmall?.copyWith(
            color: palette.textFaint,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.first});

  final VoidCallback onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Agregar foto',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Container(
          width: first ? 160 : 104,
          height: 104,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: context.colors.primary, width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: context.colors.primary,
                size: 26,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                first ? 'Agregar fotos' : 'Agregar',
                style: context.texts.labelMedium?.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.path,
    required this.isCover,
    required this.variant,
    required this.onTap,
  });

  final String path;
  final bool isCover;
  final ArtworkVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BelArtwork(imagePath: path, variant: variant),
              if (isCover)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      'Portada',
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.onPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto de perfil circular con botón de cámara.
class AvatarEditor extends StatelessWidget {
  const AvatarEditor({
    super.key,
    required this.path,
    required this.onChanged,
    this.size = 96,
    this.label = 'Foto de perfil',
  });

  final String? path;
  final ValueChanged<String?> onChanged;
  final double size;
  final String label;

  Future<void> _change(BuildContext context) async {
    final picked = await pickSinglePhoto(
      context,
      allowRemove: path != null,
      onRemove: () => onChanged(null),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar $label',
      child: GestureDetector(
        onTap: () => _change(context),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: BelArtwork(
                    imagePath: path,
                    variant: ArtworkVariant.portrait,
                    icon: path == null ? Icons.person_rounded : null,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.palette.background,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

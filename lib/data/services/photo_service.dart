import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Toma o elige fotografías y las guarda dentro de la app.
///
/// En Android/iOS la imagen se comprime y se copia a la carpeta privada de la
/// app (no depende de que el usuario conserve la foto en su galería). En web
/// se guarda como data URI. El resultado es una ruta que entiende
/// [BelArtwork].
class PhotoService {
  PhotoService._();

  static final ImagePicker _picker = ImagePicker();

  /// Con el servidor de pruebas activo, las fotos se suben ahí para que se
  /// vean en todos los teléfonos.
  static Future<String> Function(Uint8List bytes, String extension)? uploader;

  /// Elige una sola foto. Devuelve `null` si el usuario cancela.
  static Future<String?> pick(
    ImageSource source, {
    double maxWidth = 1600,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: kIsWeb ? 1000 : maxWidth,
      maxHeight: kIsWeb ? 1000 : maxWidth,
      imageQuality: kIsWeb ? 70 : 82,
    );
    if (file == null) return null;
    return _store(file);
  }

  /// Elige varias fotos de la galería (hasta [limit]).
  static Future<List<String>> pickMany({int limit = 6}) async {
    if (limit <= 0) return const [];
    final files = await _picker.pickMultiImage(
      maxWidth: kIsWeb ? 1000 : 1600,
      maxHeight: kIsWeb ? 1000 : 1600,
      imageQuality: kIsWeb ? 70 : 82,
      limit: limit > 1 ? limit : null,
    );
    final result = <String>[];
    for (final file in files.take(limit)) {
      result.add(await _store(file));
    }
    return result;
  }

  static Future<String> _store(XFile file) async {
    final upload = uploader;
    if (upload != null) {
      final name = file.name.toLowerCase();
      final extension = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '.jpg';
      return upload(await file.readAsBytes(), extension);
    }
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}${Platform.pathSeparator}photos');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final extension = file.name.contains('.')
        ? file.name.substring(file.name.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final target =
        '${folder.path}${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}$extension';
    await File(file.path).copy(target);
    return target;
  }

  /// Borra una foto guardada por la app (ignora assets y data URI).
  static Future<void> delete(String? path) async {
    if (path == null || kIsWeb || !isLocalFile(path)) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Si no se puede borrar no pasa nada: solo ocupa espacio.
    }
  }

  static bool isLocalFile(String path) =>
      !path.startsWith('assets/') &&
      !path.startsWith('data:') &&
      !path.startsWith('http');
}

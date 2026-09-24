/// Photo acquisition: camera / gallery via `image_picker`, plus decoding of
/// the pixel size so the overlay can map normalized coordinates.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

/// A photo ready for analysis: JPEG bytes plus its pixel size.
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
    this.path,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// Source path on disk when the picker provided one.
  final String? path;

  double get aspectRatio => height == 0 ? 1 : width / height;
}

/// Where the photo comes from.
enum PhotoSource { camera, gallery }

/// Picks and downsizes a photo (long side ≤ 1456 px, JPEG quality 85), then
/// decodes its dimensions with `dart:ui`.
class PhotoPicker {
  PhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxSide = 1456.0;
  static const jpegQuality = 85;

  final ImagePicker _picker;

  /// Returns null when the user cancelled.
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: jpegQuality,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return fromBytes(bytes, path: file.path);
  }

  /// Decodes [bytes] to learn its size.
  static Future<PickedPhoto> fromBytes(Uint8List bytes, {String? path}) async {
    final size = await decodeSize(bytes);
    return PickedPhoto(bytes: bytes, width: size.$1, height: size.$2, path: path);
  }

  /// Decodes only the first frame and returns `(width, height)`.
  static Future<(int, int)> decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final result = (image.width, image.height);
      image.dispose();
      return result;
    } finally {
      codec.dispose();
    }
  }
}

/// [FaceRegionDetector] backed by Google ML Kit's on-device face detection
/// (`google_mlkit_face_detection`). No image data leaves the device.
///
/// Platform notes: Android needs minSdk 21+ (Flutter's default is higher);
/// iOS needs the deployment target set to 15.5 or newer
/// (`platform :ios, '15.5'` in ios/Podfile).
library;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' as mlkit;

import 'face_blur.dart';

class MlKitFaceRegionDetector implements FaceRegionDetector {
  const MlKitFaceRegionDetector({this.minFaceSize = 0.05});

  /// Smallest face to report, as a fraction of the image width (ML Kit
  /// option). Arcade photos show bystanders far away, so keep it small.
  final double minFaceSize;

  @override
  Future<List<NormRect>> detectFaces(
    Uint8List imageBytes, {
    required int width,
    required int height,
    String? path,
  }) async {
    if (path == null || path.isEmpty || width <= 0 || height <= 0) {
      // ML Kit needs raw pixel metadata for byte input; the picker always
      // gives us a file, so bytes-only input is not supported here.
      return const [];
    }
    final detector = mlkit.FaceDetector(
      options: mlkit.FaceDetectorOptions(
        performanceMode: mlkit.FaceDetectorMode.fast,
        minFaceSize: minFaceSize,
      ),
    );
    try {
      final faces = await detector.processImage(mlkit.InputImage.fromFilePath(path));
      return [
        for (final f in faces)
          NormRect(
            (f.boundingBox.left / width).clamp(0.0, 1.0),
            (f.boundingBox.top / height).clamp(0.0, 1.0),
            (f.boundingBox.right / width).clamp(0.0, 1.0),
            (f.boundingBox.bottom / height).clamp(0.0, 1.0),
          ),
      ];
    } catch (e) {
      // Detection is best-effort: a missing ML Kit model must not block the
      // analysis. The caller reports "0 faces" and the photo is sent as is.
      debugPrint('face detection failed: $e');
      return const [];
    } finally {
      await detector.close();
    }
  }
}

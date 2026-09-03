import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class MLUtils {
  static InputImage? inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.yuv_420_888) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      debugPrint('MLUtils: Unsupported format: ${image.format.raw}');
      return null;
    }

    if (image.planes.length != 1 && Platform.isIOS) return null;
    
    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  static Uint8List _concatenatePlanes(List<Plane> planes) {
    if (planes.length == 1) return planes[0].bytes;
    
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      final bytes = plane.bytes;
      final rowStride = plane.bytesPerRow;
      final width = plane.width ?? 0;
      final height = plane.height ?? 0;

      for (int y = 0; y < height; y++) {
        allBytes.putUint8List(bytes.sublist(y * rowStride, y * rowStride + width));
      }
    }
    return allBytes.done().buffer.asUint8List();
  }
}

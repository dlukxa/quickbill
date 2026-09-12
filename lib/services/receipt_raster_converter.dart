import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Converts receipt images into ESC/POS monochrome 1-bit raster commands and bitmaps.
/// Supports standard 58mm (384 dots) and 80mm (576 dots) thermal printers.
class ReceiptRasterConverter {
  ReceiptRasterConverter._();
  static final ReceiptRasterConverter instance = ReceiptRasterConverter._();

  /// Decodes PNG bytes, scales to [targetWidth] if needed, and generates ESC/POS
  /// raster bitmap command (`GS v 0`) ready to send to a thermal printer socket or Bluetooth stream.
  List<int> convertPngToEscPosRaster(
    Uint8List pngBytes, {
    int targetWidth = 576,
    int threshold = 185,
    bool addCutCommand = true,
    int feedLines = 4,
  }) {
    final img.Image? decoded = img.decodeImage(pngBytes);
    if (decoded == null) return [];

    return convertImageToEscPosRaster(
      decoded,
      targetWidth: targetWidth,
      threshold: threshold,
      addCutCommand: addCutCommand,
      feedLines: feedLines,
    );
  }

  /// Converts an [img.Image] directly to ESC/POS `GS v 0` raster bytes.
  List<int> convertImageToEscPosRaster(
    img.Image image, {
    int targetWidth = 576,
    int threshold = 185,
    bool addCutCommand = true,
    int feedLines = 4,
  }) {
    // 1. Resize if image width does not match target printer printable width
    img.Image processed = image;
    if (processed.width != targetWidth) {
      final double scale = targetWidth / processed.width;
      final int newHeight = (processed.height * scale).round();
      processed = img.copyResize(
        processed,
        width: targetWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final int width = processed.width;
    final int height = processed.height;
    final int widthBytes = (width + 7) ~/ 8;

    final List<int> bytes = [];

    // Initialize printer: ESC @ (0x1B, 0x40)
    bytes.addAll([0x1B, 0x40]);

    // Set line spacing to 0: ESC 3 0 (0x1B, 0x33, 0x00)
    bytes.addAll([0x1B, 0x33, 0x00]);

    // ESC/POS raster bitmap command: GS v 0 0 xL xH yL yH d1...dk
    final int xL = widthBytes % 256;
    final int xH = widthBytes ~/ 256;
    final int yL = height % 256;
    final int yH = height ~/ 256;

    bytes.addAll([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

    // Binarize pixels into 1-bit monochrome data
    for (int y = 0; y < height; y++) {
      for (int xByte = 0; xByte < widthBytes; xByte++) {
        int byteVal = 0;
        for (int bit = 0; bit < 8; bit++) {
          final int x = xByte * 8 + bit;
          if (x < width) {
            final pixel = processed.getPixel(x, y);
            final lum = img.getLuminance(pixel);
            // 1 = Black thermal dot, 0 = White dot
            if (lum < threshold) {
              byteVal |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(byteVal);
      }
    }

    // Reset line spacing: ESC 2 (0x1B, 0x32)
    bytes.addAll([0x1B, 0x32]);

    // Feed paper: ESC d [feedLines] (0x1B, 0x64, [feedLines])
    if (feedLines > 0) {
      bytes.addAll([0x1B, 0x64, feedLines]);
    }

    // Partial paper cut: GS V 66 0 (0x1D, 0x56, 0x42, 0x00)
    if (addCutCommand) {
      bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    }

    return bytes;
  }

  /// Converts PNG bytes to high-contrast monochrome PNG bytes suitable for
  /// `BlueThermalPrinter.printImageBytes(bytes)`.
  Uint8List convertToMonochromePng(
    Uint8List pngBytes, {
    int targetWidth = 576,
    int threshold = 185,
  }) {
    final img.Image? decoded = img.decodeImage(pngBytes);
    if (decoded == null) return pngBytes;

    img.Image processed = decoded;
    if (processed.width != targetWidth) {
      final double scale = targetWidth / processed.width;
      final int newHeight = (processed.height * scale).round();
      processed = img.copyResize(
        processed,
        width: targetWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // Threshold into pure black and pure white
    for (int y = 0; y < processed.height; y++) {
      for (int x = 0; x < processed.width; x++) {
        final pixel = processed.getPixel(x, y);
        final lum = img.getLuminance(pixel);
        if (lum < threshold) {
          processed.setPixelRgb(x, y, 0, 0, 0); // Black
        } else {
          processed.setPixelRgb(x, y, 255, 255, 255); // White
        }
      }
    }

    return Uint8List.fromList(img.encodePng(processed));
  }
}

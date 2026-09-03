import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../../config/theme.dart';

class ObjectDetectorPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  ObjectDetectorPainter(this.objects, this.absoluteImageSize, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppTheme.primaryGreen;

    final Paint background = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final DetectedObject object in objects) {
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 16,
            textDirection: TextDirection.ltr),
      );
      builder.pushStyle(
          ui.TextStyle(color: Colors.white, background: Paint()..color = AppTheme.primaryGreen));
      
      // Show the primary label if available
      final String label = object.labels.isNotEmpty 
          ? object.labels.first.text 
          : "Object Detected";
      builder.addText(label);
      builder.pop();

      final left = translateX(object.boundingBox.left, rotation, size, absoluteImageSize);
      final top = translateY(object.boundingBox.top, rotation, size, absoluteImageSize);
      final right = translateX(object.boundingBox.right, rotation, size, absoluteImageSize);
      final bottom = translateY(object.boundingBox.bottom, rotation, size, absoluteImageSize);

      final rect = Rect.fromLTRB(left, top, right, bottom);
      
      // Draw Box
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, background);

      // Draw Corner Accents for "Tech" look
      _drawCorners(canvas, rect, paint);

      // Draw Label
      canvas.drawParagraph(
        builder.build()
          ..layout(ui.ParagraphConstraints(width: right - left)),
        Offset(left, top - 24),
      );
    }
  }
  
  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    const double cornerSize = 10.0;
    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..color = Colors.white;

    // Top Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerSize), cornerPaint);

    // Top Right
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerSize), cornerPaint);

    // Bottom Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, cornerSize), cornerPaint);

    // Bottom Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, cornerSize), cornerPaint);
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.objects != objects;
  }
}

// Coordinate Translator Helpers (Standard ML Kit Utils)
double translateX(double x, InputImageRotation rotation, Size size, Size absoluteImageSize) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x * size.width / absoluteImageSize.height;
    case InputImageRotation.rotation270deg:
      return size.width - x * size.width / absoluteImageSize.height;
    default:
      return x * size.width / absoluteImageSize.width;
  }
}

double translateY(double y, InputImageRotation rotation, Size size, Size absoluteImageSize) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y * size.height / absoluteImageSize.width;
    default:
      return y * size.height / absoluteImageSize.height;
  }
}

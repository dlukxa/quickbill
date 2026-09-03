import 'package:flutter/material.dart';

class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double boxW = constraints.maxWidth * 0.8;
        const double boxH = 140.0;
        final double left = (constraints.maxWidth - boxW) / 2;
        final double top = (constraints.maxHeight - boxH) / 2 - 40;

        return Stack(
          children: [
            // Dark Overlay with Cutout
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OverlayPainter(
                cutoutRect: Rect.fromLTWH(left, top, boxW, boxH),
              ),
            ),
            
            // Scan Corners
            Positioned(
              left: left,
              top: top,
              child: SizedBox(
                width: boxW,
                height: boxH,
                child: const CustomPaint(
                  painter: _ScanCornersPainter(),
                ),
              ),
            ),

            // Instruction Text
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Align barcode within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;

  _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    
    // Draw rectangles around the cutout
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cutoutRect.top), paint);
    canvas.drawRect(Rect.fromLTWH(0, cutoutRect.bottom, size.width, size.height - cutoutRect.bottom), paint);
    canvas.drawRect(Rect.fromLTWH(0, cutoutRect.top, cutoutRect.left, cutoutRect.height), paint);
    canvas.drawRect(Rect.fromLTWH(cutoutRect.right, cutoutRect.top, size.width - cutoutRect.right, cutoutRect.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanCornersPainter extends CustomPainter {
  const _ScanCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white // Assuming AppTheme.primaryGreen is Colors.white or similar for this example
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerSize = 40.0;
    
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

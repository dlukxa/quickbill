import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  /// Show options for barcode input (Camera scan or Manual entry)
  static Future<String?> showScanOptions(BuildContext context) async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Scan Barcode',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.camera_alt),
              ),
              title: const Text('Camera Scanner'),
              subtitle: const Text('Use camera to scan barcode'),
              onTap: () async {
                Navigator.pop(context);
                final barcode = await scanBarcode(context);
                if (context.mounted && barcode != null) {
                  Navigator.pop(context, barcode);
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.keyboard),
              ),
              title: const Text('Manual Entry'),
              subtitle: const Text('Type barcode manually'),
              onTap: () async {
                Navigator.pop(context);
                final barcode = await _showManualEntry(context);
                if (context.mounted && barcode != null) {
                  Navigator.pop(context, barcode);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Show manual barcode entry dialog
  static Future<String?> _showManualEntry(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            hintText: 'Enter barcode number',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<String?> scanBarcode(BuildContext context) async {
    return await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const _BarcodeScannerScreen(),
      ),
    );
  }
}

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null && code.isNotEmpty) {
      setState(() {
        _isScanned = true;
      });

      // Vibrate/haptic feedback
      // HapticFeedback.vibrate();

      // Return the scanned code
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // Scanning overlay
          CustomPaint(
            painter: _ScannerOverlay(),
            child: const SizedBox.expand(),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Position barcode within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Flash button
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: () => cameraController.toggleTorch(),
                icon: ValueListenableBuilder(
                  valueListenable: cameraController,
                  builder: (context, state, child) {
                    final torchState = state.torchState;
                    return Icon(
                      torchState == TorchState.off ? Icons.flash_off : Icons.flash_on,
                      color: Colors.white,
                      size: 32,
                    );
                  },
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final double scanAreaWidth = size.width * 0.8;
    final double scanAreaHeight = 140.0;
    final double left = (size.width - scanAreaWidth) / 2;
    final double top = (size.height - scanAreaHeight) / 2 - 40;

    // Draw the overlay with a transparent scanning area
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanAreaWidth, scanAreaHeight),
          const Radius.circular(12),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
    final Paint bracketPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const double bracketLength = 30;

    // Top-left corner
    canvas.drawLine(Offset(left, top + bracketLength), Offset(left, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left + bracketLength, top), bracketPaint);

    // Top-right corner
    canvas.drawLine(Offset(left + scanAreaWidth - bracketLength, top), Offset(left + scanAreaWidth, top), bracketPaint);
    canvas.drawLine(Offset(left + scanAreaWidth, top), Offset(left + scanAreaWidth, top + bracketLength), bracketPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, top + scanAreaHeight - bracketLength), Offset(left, top + scanAreaHeight), bracketPaint);
    canvas.drawLine(Offset(left, top + scanAreaHeight), Offset(left + bracketLength, top + scanAreaHeight), bracketPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(left + scanAreaWidth - bracketLength, top + scanAreaHeight), Offset(left + scanAreaWidth, top + scanAreaHeight), bracketPaint);
    canvas.drawLine(Offset(left + scanAreaWidth, top + scanAreaHeight - bracketLength), Offset(left + scanAreaWidth, top + scanAreaHeight), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

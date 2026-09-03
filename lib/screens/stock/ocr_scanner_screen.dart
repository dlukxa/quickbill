import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/batch_ocr_service.dart';
import '../../widgets/scan/camera_view.dart';
import '../../utils/region_utils.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;

  String? _batchNumber;
  DateTime? _expiryDate;
  DateTime? _mfgDate;
  double? _mrp;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void _onImage(InputImage inputImage) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;
      
      debugPrint("================ OCR STREAM FRAME ================");
      debugPrint(rawText);
      debugPrint("==================================================");

      final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      final batch = BatchOcrService.extractBatchNumber(lines);
      final exp = BatchOcrService.extractDate(lines, isExpiry: true);
      final mfd = BatchOcrService.extractDate(lines, isExpiry: false);
      final price = BatchOcrService.extractMRP(lines);

      if (batch != null || exp != null || mfd != null || price != null) {
        setState(() {
          if (batch != null) _batchNumber = batch;
          if (exp != null) _expiryDate = exp;
          if (mfd != null) _mfgDate = mfd;
          if (price != null) _mrp = price;
        });
      }
    } catch (e) {
      debugPrint("Real-time OCR processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _batchNumber != null || _expiryDate != null || _mfgDate != null || _mrp != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Label Scanner',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Real-time camera view stream
          CameraView(
            customPaint: null,
            onImage: _onImage,
          ),

          // Transparent scanning viewport overlay with brackets
          IgnorePointer(
            child: CustomPaint(
              painter: _OcrViewportOverlay(),
              child: const SizedBox.expand(),
            ),
          ),

          // Floating Real-time Results Overlay Card
          Positioned(
            bottom: 120,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE DETECTED DETAILS',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (hasAny)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                          onPressed: () {
                            setState(() {
                              _batchNumber = null;
                              _expiryDate = null;
                              _mfgDate = null;
                              _mrp = null;
                            });
                          },
                          tooltip: 'Clear/Reset',
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  _buildFieldRow('Batch No (B/NO):', _batchNumber ?? 'Scanning...', _batchNumber != null),
                  _buildFieldRow('Expiry Date (EXP):', _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : 'Scanning...', _expiryDate != null),
                  _buildFieldRow('Mfg Date (MFD):', _mfgDate != null ? DateFormat('yyyy-MM-dd').format(_mfgDate!) : 'Scanning...', _mfgDate != null),
                  _buildFieldRow('MRP / Cost:', _mrp != null ? '${globalAppRegion.currencySymbol} ${_mrp!.toStringAsFixed(2)}' : 'Scanning...', _mrp != null),
                ],
              ),
            ),
          ),

          // Action Controls
          Positioned(
            bottom: 30,
            left: 32,
            right: 32,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: hasAny
                        ? () {
                            Navigator.pop(
                              context,
                              BatchOcrResult(
                                batchNumber: _batchNumber,
                                expiryDate: _expiryDate,
                                mfgDate: _mfgDate,
                                mrp: _mrp,
                                rawText: '',
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.check, size: 20),
                    label: Text(
                      'Apply Detected Details',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, bool isDetected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: isDetected ? AppTheme.primaryGreen : Colors.white38,
                  fontWeight: isDetected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isDetected ? Icons.check_circle : Icons.circle_outlined,
                color: isDetected ? AppTheme.primaryGreen : Colors.white12,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OcrViewportOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Viewport box parameters
    final double viewWidth = size.width * 0.85;
    final double viewHeight = size.height * 0.3;
    final double left = (size.width - viewWidth) / 2;
    final double top = (size.height - viewHeight) / 2 - 80;

    // Cut a viewport hole in the screen shade
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, viewWidth, viewHeight),
          const Radius.circular(16),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw viewport borders
    final Paint borderPaint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, viewWidth, viewHeight),
        const Radius.circular(16),
      ),
      borderPaint,
    );

    // Draw bright green bracket corners
    final Paint bracketPaint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const double len = 25;

    // Top-left
    canvas.drawLine(Offset(left, top + len), Offset(left, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left + len, top), bracketPaint);

    // Top-right
    canvas.drawLine(Offset(left + viewWidth - len, top), Offset(left + viewWidth, top), bracketPaint);
    canvas.drawLine(Offset(left + viewWidth, top), Offset(left + viewWidth, top + len), bracketPaint);

    // Bottom-left
    canvas.drawLine(Offset(left, top + viewHeight - len), Offset(left, top + viewHeight), bracketPaint);
    canvas.drawLine(Offset(left, top + viewHeight), Offset(left + len, top + viewHeight), bracketPaint);

    // Bottom-right
    canvas.drawLine(Offset(left + viewWidth - len, top + viewHeight), Offset(left + viewWidth, top + viewHeight), bracketPaint);
    canvas.drawLine(Offset(left + viewWidth, top + viewHeight - len), Offset(left + viewWidth, top + viewHeight), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

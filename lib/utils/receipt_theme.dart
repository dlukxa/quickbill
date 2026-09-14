import 'package:flutter/material.dart';

/// Standardized typography and layout metrics for thermal receipt rendering.
/// Pure black (#000000) on white (#FFFFFF) ensures ultra-sharp monochrome thermal raster output.
class ReceiptTheme {
  ReceiptTheme._();

  static const String fontFamily = 'NotoSansSinhala';
  static const List<String> fontFamilyFallback = [
    'NotoSans',
    'Roboto',
    'sans-serif',
  ];

  // ─── Metrics ───
  // 58mm standard: 48mm printable area * 8 dots/mm = 384 pixels
  static const double width58mm = 384.0;
  // 80mm standard: 72mm printable area * 8 dots/mm = 576 pixels
  static const double width80mm = 576.0;

  static double getReceiptWidth(bool is58mm) => is58mm ? width58mm : width80mm;

  // ─── Text Styles ───
  static TextStyle textStyle({
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    double height = 1.25,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  static TextStyle storeTitle(bool is58mm) => textStyle(
        fontSize: is58mm ? 16.0 : 20.0,
        fontWeight: FontWeight.w800,
        height: 1.2,
      );

  static TextStyle storeSubtitle(bool is58mm) => textStyle(
        fontSize: is58mm ? 10.0 : 12.0,
        fontWeight: FontWeight.normal,
        height: 1.25,
      );

  static TextStyle metaText(bool is58mm, {bool isBold = false}) => textStyle(
        fontSize: is58mm ? 9.5 : 12.0,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        height: 1.25,
      );

  static TextStyle tableHeader(bool is58mm) => textStyle(
        fontSize: is58mm ? 9.5 : 11.5,
        fontWeight: FontWeight.w800,
        height: 1.2,
      );

  static TextStyle itemName(bool is58mm) => textStyle(
        fontSize: is58mm ? 11.0 : 13.5,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle itemDetail(bool is58mm, {bool isBold = false}) => textStyle(
        fontSize: is58mm ? 10.0 : 12.0,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
        height: 1.25,
      );

  static TextStyle itemDiscount(bool is58mm) => textStyle(
        fontSize: is58mm ? 9.0 : 11.0,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle summaryLabel(bool is58mm, {bool isBold = false}) => textStyle(
        fontSize: is58mm ? 10.5 : 13.0,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
        height: 1.25,
      );

  static TextStyle summaryValue(bool is58mm, {bool isBold = false}) => textStyle(
        fontSize: is58mm ? 10.5 : 13.0,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
        height: 1.25,
      );

  static TextStyle savingsLabel(bool is58mm) => textStyle(
        fontSize: is58mm ? 12.0 : 14.5,
        fontWeight: FontWeight.w800,
        height: 1.25,
      );

  static TextStyle savingsValue(bool is58mm) => textStyle(
        fontSize: is58mm ? 12.5 : 15.0,
        fontWeight: FontWeight.w900,
        height: 1.25,
      );

  static TextStyle grandTotalLabel(bool is58mm) => textStyle(
        fontSize: is58mm ? 15.0 : 18.0,
        fontWeight: FontWeight.w900,
        height: 1.2,
      );

  static TextStyle grandTotalValue(bool is58mm) => textStyle(
        fontSize: is58mm ? 16.0 : 20.0,
        fontWeight: FontWeight.w900,
        height: 1.2,
      );

  static TextStyle footerThankYou(bool is58mm) => textStyle(
        fontSize: is58mm ? 11.5 : 14.0,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle footerCredit(bool is58mm) => textStyle(
        fontSize: is58mm ? 8.5 : 10.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );
}

/// Custom dashed divider optimized for thermal receipt rendering
class ReceiptDashedDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  const ReceiptDashedDivider({
    super.key,
    this.height = 10.0,
    this.thickness = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          size: Size(double.infinity, thickness),
          painter: _DashedLinePainter(
            thickness: thickness,
            dashWidth: dashWidth,
            dashSpace: dashSpace,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double thickness;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  _DashedLinePainter({
    required this.thickness,
    required this.dashWidth,
    required this.dashSpace,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth > size.width ? size.width : startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.thickness != thickness ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace ||
      oldDelegate.color != color;
}

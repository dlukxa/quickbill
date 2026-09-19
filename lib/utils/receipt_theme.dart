import 'package:flutter/material.dart';
import '../providers/preference_provider.dart';

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

  static double getReceiptWidth(bool is58mm, {AppSettings? settings}) {
    if (settings != null) return settings.effectiveReceiptWidthPx;
    return is58mm ? width58mm : width80mm;
  }

  // ─── Text Styles ───
  static TextStyle textStyle({
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.black,
    double height = 1.25,
    TextDecoration? decoration,
    bool forceBold = false,
  }) {
    final effectiveWeight = forceBold
        ? (fontWeight == FontWeight.normal ? FontWeight.w700 : FontWeight.w900)
        : fontWeight;

    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: effectiveWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  static TextStyle storeTitle(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptStoreNameFontSize ?? (is58mm ? 16.0 : 20.0);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    final bool bold = settings?.receiptBoldText ?? false;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 60.0),
      fontWeight: FontWeight.w800,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle storeSubtitle(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptMainFontSize * 0.9)
        : (is58mm ? 10.0 : 12.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    final bool bold = settings?.receiptBoldText ?? false;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 48.0),
      fontWeight: FontWeight.normal,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle metaText(bool is58mm, {bool isBold = false, AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (isBold ? settings.receiptMainFontSize : settings.receiptMainFontSize * 0.95)
        : (is58mm ? 9.5 : 12.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    final bool bold = (settings?.receiptBoldText ?? false) || isBold;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 40.0),
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle tableHeader(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptMainFontSize * 0.95)
        : (is58mm ? 9.5 : 11.5);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 40.0),
      fontWeight: FontWeight.w800,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle itemName(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptProductNameFontSize ?? (is58mm ? 11.0 : 13.5);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 48.0),
      fontWeight: FontWeight.w700,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle itemDetail(bool is58mm, {bool isBold = false, AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptQtyPriceFontSize ?? (is58mm ? 10.0 : 12.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    final bool bold = (settings?.receiptBoldText ?? false) || isBold;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 44.0),
      fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle itemDiscount(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptDiscountFontSize * 0.88)
        : (is58mm ? 9.0 : 11.0);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 36.0),
      fontWeight: FontWeight.w500,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle summaryLabel(bool is58mm, {bool isBold = false, AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptSubtotalFontSize ?? (is58mm ? 10.5 : 13.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    final bool bold = (settings?.receiptBoldText ?? false) || isBold;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 44.0),
      fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle summaryValue(bool is58mm, {bool isBold = false, AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptSubtotalFontSize ?? (is58mm ? 10.5 : 13.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    final bool bold = (settings?.receiptBoldText ?? false) || isBold;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 44.0),
      fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
      height: height,
      forceBold: bold,
    );
  }

  static TextStyle savingsLabel(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptDiscountFontSize ?? (is58mm ? 12.0 : 14.5);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 48.0),
      fontWeight: FontWeight.w800,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle savingsValue(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptDiscountFontSize * 1.05)
        : (is58mm ? 12.5 : 15.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 50.0),
      fontWeight: FontWeight.w900,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle grandTotalLabel(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptGrandTotalFontSize ?? (is58mm ? 15.0 : 18.0);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    return textStyle(
      fontSize: (baseSize * scale).clamp(10.0, 56.0),
      fontWeight: FontWeight.w900,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle grandTotalValue(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptGrandTotalFontSize * 1.1)
        : (is58mm ? 16.0 : 20.0);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    return textStyle(
      fontSize: (baseSize * scale).clamp(10.0, 60.0),
      fontWeight: FontWeight.w900,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle footerThankYou(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings?.receiptFooterFontSize ?? (is58mm ? 11.5 : 14.0);
    final double height = settings?.receiptLineSpacing ?? 1.25;
    return textStyle(
      fontSize: (baseSize * scale).clamp(8.0, 48.0),
      fontWeight: FontWeight.w700,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }

  static TextStyle footerCredit(bool is58mm, {AppSettings? settings}) {
    final double scale = settings?.receiptFontScale ?? 1.0;
    final double baseSize = settings != null
        ? (settings.receiptFooterFontSize * 0.85)
        : (is58mm ? 8.5 : 10.5);
    final double height = settings?.receiptLineSpacing ?? 1.2;
    return textStyle(
      fontSize: (baseSize * scale).clamp(7.0, 40.0),
      fontWeight: FontWeight.w500,
      height: height,
      forceBold: settings?.receiptBoldText ?? false,
    );
  }
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

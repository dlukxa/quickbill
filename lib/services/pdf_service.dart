import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../utils/region_utils.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../utils/formatters.dart';
import '../utils/pos_l10n.dart';
import '../providers/preference_provider.dart';
import 'receipt_image_generator.dart';

class PdfService {
  static final PdfService instance = PdfService._internal();

  PdfService._internal();

  pw.ThemeData? _theme;
  bool _fontLoadAttempted = false;

  /// Call this early in app lifecycle to pre-load PDF fonts.
  /// Safe to call multiple times — only loads once.
  Future<void> preWarmFonts() async {
    if (_theme != null || _fontLoadAttempted) return;
    await _getTheme();
  }

  Future<pw.ThemeData> _getTheme() async {
    if (_theme != null) return _theme!;
    _fontLoadAttempted = true;

    // ─── Strategy: Use NotoSansSinhala as the PRIMARY base font.
    // This ensures Sinhala glyphs render correctly without any fallback lookup.
    // NotoSans (Latin) is added as a fontFallback for English/numbers.
    // This fixes garbled/broken Sinhala characters in generated PDFs.

    pw.Font? sinhalaRegular;
    pw.Font? sinhalaBold;   // NotoSansSinhala doesn't ship a Bold TTF; we use SemiBold from Google
    pw.Font? latinRegular;
    pw.Font? latinBold;
    pw.Font? tamilFont;

    // 1. Load bundled Sinhala fonts (primary) — always offline
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
      sinhalaRegular = pw.Font.ttf(data);
      debugPrint('PDF: Loaded bundled NotoSansSinhala-Regular');
    } catch (e) {
      debugPrint('PDF: NotoSansSinhala-Regular load error: $e');
    }

    try {
      final data = await rootBundle.load('assets/fonts/NotoSansSinhala-Bold.ttf');
      sinhalaBold = pw.Font.ttf(data);
      debugPrint('PDF: Loaded bundled NotoSansSinhala-Bold');
    } catch (e) {
      debugPrint('PDF: NotoSansSinhala-Bold load error: $e');
    }

    // 2. Load bundled Latin NotoSans (used as fallback for ASCII/numbers)
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      latinRegular = pw.Font.ttf(data);
      debugPrint('PDF: Loaded bundled NotoSans-Regular');
    } catch (e) {
      debugPrint('PDF: NotoSans-Regular load error: $e');
    }

    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      latinBold = pw.Font.ttf(data);
      debugPrint('PDF: Loaded bundled NotoSans-Bold');
    } catch (e) {
      debugPrint('PDF: NotoSans-Bold load error: $e');
    }

    // 3. Google Fonts fallback for anything missing from assets
    sinhalaRegular ??= await _tryGoogleFont(PdfGoogleFonts.notoSansSinhalaRegular);
    sinhalaBold ??= await _tryGoogleFont(PdfGoogleFonts.notoSansSinhalaSemiBold);
    latinRegular ??= await _tryGoogleFont(PdfGoogleFonts.notoSansRegular) ?? pw.Font.helvetica();
    latinBold ??= await _tryGoogleFont(PdfGoogleFonts.notoSansBold) ?? pw.Font.helveticaBold();
    tamilFont = await _tryGoogleFont(PdfGoogleFonts.notoSansTamilRegular);

    // 4. Resolve effective base: prefer Sinhala as primary for correct Unicode shaping
    final effectiveBase = sinhalaRegular ?? latinRegular;
    final effectiveBold = sinhalaBold ?? sinhalaRegular ?? latinBold;

    // 5. fontFallback list — Latin first (numbers/English), then Tamil
    final fontFallbacks = <pw.Font>[
      if (latinRegular != null) latinRegular,
      if (latinBold != null) latinBold,
      if (tamilFont != null) tamilFont,
    ];

    try {
      _theme = pw.ThemeData.withFont(
        base: effectiveBase,
        bold: effectiveBold,
        italic: effectiveBase,
        boldItalic: effectiveBold,
        fontFallback: fontFallbacks,
      );
      debugPrint('PDF: Theme created — base=NotoSansSinhala, fallbacks=${fontFallbacks.length}');
    } catch (e) {
      debugPrint('PDF: Error creating theme: $e — falling back to base theme');
      _theme = pw.ThemeData.base();
    }
    return _theme!;
  }

  Future<pw.Font?> _tryGoogleFont(Future<pw.Font> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<pw.Document> buildReceiptDocument(
    Sale sale,
    List<SaleItem> items, {
    AppSettings? settings,
    String? overridePaperSize,
    double? cashReceived,
    double? change,
  }) async {
    final effectiveSettings = _resolveSettings(settings);
    final bool is58mm = overridePaperSize == '58mm' || (overridePaperSize == null && effectiveSettings.is58mm);

    // If Sinhala characters or non-English receipt settings are present,
    // render through the Flutter offscreen image generator for 100% accurate HarfBuzz text shaping
    if (_hasSinhalaContent(sale, items, settings)) {
      final pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sale,
        items: items,
        settings: effectiveSettings,
        cashReceived: cashReceived,
        change: change,
        overridePaperSize: overridePaperSize,
      );
      return buildImageReceiptDocument(pngBytes, is58mm: is58mm);
    }

    final template = settings?.receiptTemplate ?? 'sri_lankan_retail';
    if (template == 'classic') {
      return _buildClassicReceipt(
        sale,
        items,
        settings: settings,
        overridePaperSize: overridePaperSize,
        cashReceived: cashReceived,
        change: change,
      );
    } else {
      return _buildSriLankanRetailReceipt(
        sale,
        items,
        settings: settings,
        overridePaperSize: overridePaperSize,
        cashReceived: cashReceived,
        change: change,
      );
    }
  }

  bool _hasSinhalaContent(Sale sale, List<SaleItem> items, AppSettings? settings) {
    if (settings != null) {
      if (settings.receiptLanguage != 'en') return true;
      if (settings.receiptTemplate == 'sri_lankan_retail') return true;
      if (_containsSinhalaChars(settings.shopName)) return true;
      if (_containsSinhalaChars(settings.shopAddress)) return true;
      if (_containsSinhalaChars(settings.receiptFooter)) return true;
    }
    if (sale.cashierName != null && _containsSinhalaChars(sale.cashierName!)) return true;
    if (sale.customerName != null && _containsSinhalaChars(sale.customerName!)) return true;
    for (final item in items) {
      if (_containsSinhalaChars(item.productName)) return true;
    }
    return false;
  }

  bool _containsSinhalaChars(String text) {
    for (final rune in text.runes) {
      if (rune >= 0x0D80 && rune <= 0x0DFF) return true;
    }
    return false;
  }

  AppSettings _resolveSettings(AppSettings? settings) {
    if (settings != null) return settings;
    return AppSettings(
      shopName: 'QuickBill Store',
      shopAddress: '',
      shopPhone: '',
      lowStockThreshold: 10,
      receiptFooter: 'Thank you for shopping!',
      languageCode: 'si',
      regionCode: 'LK',
      businessType: 'Retail',
      isSetupComplete: true,
      autoSync: false,
      entityCode: '1',
      printerPaperSize: '80mm',
      receiptTemplate: 'sri_lankan_retail',
      receiptLanguage: 'si',
    );
  }

  /// Builds a PDF Document from a high-resolution raster receipt image (e.g. Flutter-rendered Sinhala receipt).
  Future<pw.Document> buildImageReceiptDocument(
    Uint8List pngBytes, {
    required bool is58mm,
  }) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    final double pageWidth = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;

    // Decode image to compute proper page aspect ratio
    final decoded = img.decodeImage(pngBytes);
    final double aspectRatio = (decoded != null && decoded.width > 0)
        ? (decoded.height / decoded.width)
        : 1.8;
    final double pageHeight = pageWidth * aspectRatio;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight, marginAll: 0),
        build: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(image, fit: pw.BoxFit.fill),
        ),
      ),
    );
    return doc;
  }

  /// ─────────────────────────────────────────────────────────────
  /// TEMPLATE 2: SRI LANKAN RETAIL POS RECEIPT (Reference Layout)
  /// ─────────────────────────────────────────────────────────────
  Future<pw.Document> _buildSriLankanRetailReceipt(
    Sale sale,
    List<SaleItem> items, {
    AppSettings? settings,
    String? overridePaperSize,
    double? cashReceived,
    double? change,
  }) async {
    final doc = pw.Document();
    final l10n = ReceiptL10n.of(settings?.receiptLanguage ?? 'si');

    final shopName = (settings?.shopName.isNotEmpty == true ? settings!.shopName : 'QUICKBILL STORE').toUpperCase();
    final shopAddress = settings?.shopAddress ?? '';
    final shopPhone = settings?.shopPhone ?? '';
    final footer = settings?.receiptFooter.isNotEmpty == true 
        ? settings!.receiptFooter 
        : l10n.thankYou;
    final shopLogoUrl = settings?.shopLogoUrl;

    // Configurable field visibility toggles
    final showLogo = settings?.showReceiptLogo ?? true;
    final showBarcode = settings?.showReceiptBarcode ?? true;
    final showStdPrice = settings?.showReceiptStandardPrice ?? true;
    final showOurPrice = settings?.showReceiptOurPrice ?? true;
    final showDiscount = settings?.showReceiptDiscount ?? true;
    final showTax = settings?.showReceiptTax ?? true;
    final showPaymentDetails = settings?.showReceiptPaymentDetails ?? true;
    final showCashier = settings?.showReceiptCashier ?? true;
    final showCustomer = settings?.showReceiptCustomer ?? true;
    final showProfit = settings?.showReceiptProfit ?? false;
    final showCostPrice = settings?.showReceiptCostPrice ?? false;

    final bool is58mm = overridePaperSize == '58mm' || (overridePaperSize == null && (settings?.is58mm ?? false));
    final double pageWidth = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;

    // Typography sizing calibrated for high-density retail thermal printing
    final double titleFontSize = is58mm ? 11.0 : 13.5;
    final double headerFontSize = is58mm ? 7.0 : 8.5;
    final double bodyFontSize = is58mm ? 7.0 : 8.2;
    final double smallFontSize = is58mm ? 6.0 : 7.0;
    final double totalFontSize = is58mm ? 11.5 : 14.0;

    // Column widths for 3-column retail table (භාණ්ඩය, ප්‍රමාණය, මිල)
    final double qtyColWidth = is58mm ? 26.0 : 36.0;
    final double priceColWidth = is58mm ? 36.0 : 48.0;

    // Parse effective cash received & change from arguments or sale.notes
    double? effectiveCashReceived = cashReceived;
    double? effectiveChange = change;

    if (effectiveCashReceived == null && sale.paymentMethod.toLowerCase() == 'cash' && sale.notes != null) {
      final cashMatch = RegExp(r'(?:Cash|Received):\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (cashMatch != null) {
        effectiveCashReceived = double.tryParse(cashMatch.group(1)!);
      }
      final changeMatch = RegExp(r'Change:\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (changeMatch != null) {
        effectiveChange = double.tryParse(changeMatch.group(1)!);
      }
    }
    if (effectiveCashReceived != null && effectiveChange == null) {
      effectiveChange = (effectiveCashReceived - sale.total).clamp(0.0, double.infinity);
    }

    String formatQty(SaleItem item) {
      final qty = item.soldQuantity ?? item.quantity;
      final numStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
      if (item.soldUnit != null && item.soldUnit!.isNotEmpty && item.soldUnit != 'pcs' && item.soldUnit != 'piece') {
        return '$numStr ${item.soldUnit}';
      }
      return numStr;
    }

    String totalPieces(List<SaleItem> itemsList) {
      double sum = 0;
      for (final i in itemsList) {
        sum += (i.soldQuantity ?? i.quantity);
      }
      return sum == sum.roundToDouble() ? sum.toInt().toString() : sum.toStringAsFixed(1);
    }

    // Accurate calculation helpers
    double itemQty(SaleItem item) => item.soldQuantity ?? item.quantity;

    double itemStdPrice(SaleItem item) {
      final q = itemQty(item);
      if (item.unitPrice > 0) return item.unitPrice;
      return q > 0 ? (item.total + item.discount) / q : item.total;
    }

    double itemOurPrice(SaleItem item) {
      final q = itemQty(item);
      return q > 0 ? item.total / q : item.total;
    }

    double itemSavings(SaleItem item) {
      final q = itemQty(item);
      final stdTotal = itemStdPrice(item) * (q > 0 ? q : 1);
      final diff = stdTotal - item.total;
      return diff > item.discount ? diff : item.discount;
    }

    double itemProfit(SaleItem item) {
      final cost = item.costPrice * item.quantity;
      return item.total - cost;
    }

    final double grossStandardTotal = items.fold(0.0, (sum, i) => sum + (itemStdPrice(i) * (itemQty(i) > 0 ? itemQty(i) : 1)));
    final double subtotalOurPrice = items.fold(0.0, (sum, i) => sum + i.total);
    final double totalItemDiscounts = items.fold(0.0, (sum, i) => sum + itemSavings(i));
    final double totalDiscount = totalItemDiscounts + sale.discount;
    final double totalCost = items.fold(0.0, (sum, i) => sum + (i.costPrice * i.quantity));
    final double totalMerchantProfit = items.fold(0.0, (sum, i) => sum + itemProfit(i)) - sale.discount;

    final double remainingAmt = (effectiveCashReceived != null && effectiveCashReceived < sale.total)
        ? (sale.total - effectiveCashReceived).clamp(0.0, double.infinity)
        : (sale.paymentMethod.toLowerCase() == 'credit' ? sale.total : 0.0);

    // Height calculation calibrated to content
    final double headerHeightMm = (showLogo && shopLogoUrl != null && shopLogoUrl.isNotEmpty ? (is58mm ? 18.0 : 24.0) : 0.0)
        + 8.0 // Store name
        + (shopAddress.isNotEmpty ? 4.5 : 0.0)
        + (shopPhone.isNotEmpty ? 4.5 : 0.0)
        + 6.0 // Divider
        + 12.0 // Bill No, Date, Time
        + (showCashier ? 4.5 : 0.0)
        + (showCustomer && sale.customerName?.isNotEmpty == true ? 4.5 : 0.0);
    
    const double tableHeaderHeightMm = 7.0;

    double itemsHeightMm = 0.0;
    for (final item in items) {
      final int nameCharsPerLine = is58mm ? 18 : 28;
      final int nameLines = (item.productName.length / nameCharsPerLine).ceil().clamp(1, 4);
      itemsHeightMm += (nameLines * 3.5) + 4.5;
      final savings = itemSavings(item);
      if (savings > 0 || (itemStdPrice(item) != itemOurPrice(item))) {
        itemsHeightMm += 3.5;
      }
    }

    final double summaryHeightMm = 14.0 // Standard/Our price & subtotal
        + (showDiscount && totalDiscount > 0 ? 8.0 : 0.0)
        + (showTax && sale.tax > 0 ? 4.5 : 0.0)
        + (sale.serviceCharge > 0 ? 4.5 : 0.0)
        + (showCostPrice ? 4.5 : 0.0)
        + (showProfit ? 4.5 : 0.0)
        + 12.0 // Grand total box
        + (showPaymentDetails ? (effectiveCashReceived != null ? 14.0 : 6.0) : 0.0)
        + (remainingAmt > 0 ? 4.5 : 0.0)
        + 7.0; // Items count

    final double footerHeightMm = 12.0 // Thank you & Powered by
        + (showBarcode ? (is58mm ? 14.0 : 16.0) : 0.0);

    final double totalHeightMm = headerHeightMm + tableHeaderHeightMm + itemsHeightMm + summaryHeightMm + footerHeightMm + 10.0;
    final double pageHeight = totalHeightMm * PdfPageFormat.mm;

    final pageMargin = is58mm 
        ? const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5)
        : const pw.EdgeInsets.symmetric(horizontal: 4.5, vertical: 5.0);

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginTop: pageMargin.top,
      marginBottom: pageMargin.bottom,
      marginLeft: pageMargin.left,
      marginRight: pageMargin.right,
    );

    pw.ImageProvider? logoImage;
    if (showLogo && shopLogoUrl != null && shopLogoUrl.isNotEmpty) {
      try {
        logoImage = await networkImage(shopLogoUrl);
      } catch (e) {
        debugPrint('Error loading shop logo for receipt: $e');
      }
    }

    pw.Widget buildSummaryRow(String label, String value, {double fontSize = 7.5, bool isBold = false, PdfColor? color}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      );
    }

    pw.Widget buildDashedDivider({double height = 4.0, double thickness = 0.8}) {
      return pw.Container(
        margin: pw.EdgeInsets.symmetric(vertical: height / 2),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
              style: pw.BorderStyle.dashed,
              width: thickness,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    doc.addPage(
      pw.Page(
        theme: await _getTheme(),
        pageFormat: pageFormat,
        margin: pageMargin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── 1. STORE LOGO & HEADER ──
              if (logoImage != null)
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2.5),
                    child: pw.Image(
                      logoImage,
                      width: is58mm ? 36 : 50,
                      height: is58mm ? 26 : 36,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  shopName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleFontSize, lineSpacing: 1.05),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (shopAddress.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Center(
                    child: pw.Text(
                      shopAddress,
                      style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.05),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              if (shopPhone.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.0),
                  child: pw.Center(
                    child: pw.Text(
                      '${l10n.phone}: $shopPhone',
                      style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.05),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              pw.SizedBox(height: 2),
              buildDashedDivider(height: 4, thickness: 0.8),

              // ── 2. METADATA BLOCK ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${l10n.billNo}: ${sale.billNumber}', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('yyyy-MM-dd').format(sale.createdAt), style: pw.TextStyle(fontSize: bodyFontSize)),
                ],
              ),
              pw.SizedBox(height: 1.0),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (showCashier)
                    pw.Text('${l10n.cashier}: ${sale.cashierName?.isNotEmpty == true ? sale.cashierName : "Admin"}', style: pw.TextStyle(fontSize: bodyFontSize))
                  else
                    pw.SizedBox(),
                  pw.Text(DateFormat('hh:mm a').format(sale.createdAt), style: pw.TextStyle(fontSize: bodyFontSize)),
                ],
              ),
              if (showCustomer && sale.customerName?.isNotEmpty == true) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l10n.customer}: ${sale.customerName}', style: pw.TextStyle(fontSize: bodyFontSize)),
                    if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                      pw.Text(sale.customerPhone!, style: pw.TextStyle(fontSize: smallFontSize)),
                  ],
                ),
              ],
              buildDashedDivider(height: 4, thickness: 0.8),

              // ── 3. 4-COLUMN SUPERMARKET ITEM TABLE HEADER ──
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: is58mm ? 34 : 38,
                    child: pw.Text(
                      l10n.qtyDescHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: is58mm ? 20 : 18,
                    child: pw.Text(
                      l10n.priceHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: is58mm ? 22 : 21,
                    child: pw.Text(
                      l10n.ourPrice,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: is58mm ? 24 : 23,
                    child: pw.Text(
                      l10n.totalHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              buildDashedDivider(height: 3, thickness: 0.6),

              // ── 4. TABLE ITEMS ──
              for (final item in items) ...[
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Item Name (Bold)
                      pw.Text(
                        item.productName,
                        style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold, lineSpacing: 1.1),
                      ),
                      // 4-Column Values: Qty | Std Price | Our Price | Total
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: is58mm ? 34 : 38,
                            child: pw.Text(
                              formatQty(item),
                              style: pw.TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          pw.Expanded(
                            flex: is58mm ? 20 : 18,
                            child: pw.Text(
                              Formatters.number(itemStdPrice(item), decimalPlaces: 2),
                              style: pw.TextStyle(fontSize: bodyFontSize),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: is58mm ? 22 : 21,
                            child: pw.Text(
                              Formatters.number(itemOurPrice(item), decimalPlaces: 2),
                              style: pw.TextStyle(fontSize: bodyFontSize),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: is58mm ? 24 : 23,
                            child: pw.Text(
                              Formatters.number(item.total, decimalPlaces: 2),
                              style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              buildDashedDivider(height: 4, thickness: 0.8),

              // ── 5. FINANCIAL BREAKDOWN ──
              buildSummaryRow(l10n.subtotal, Formatters.number(grossStandardTotal > 0 ? grossStandardTotal : subtotalOurPrice, decimalPlaces: 2), fontSize: bodyFontSize),
              if (showDiscount && totalDiscount > 0) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(l10n.profit, Formatters.number(totalDiscount, decimalPlaces: 2), fontSize: bodyFontSize, isBold: true),
              ],
              pw.SizedBox(height: 1.0),
              buildSummaryRow(l10n.returns, '0.00', fontSize: bodyFontSize),

              if (showTax && sale.tax > 0) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(l10n.tax, Formatters.number(sale.tax, decimalPlaces: 2), fontSize: bodyFontSize),
              ],
              if (sale.serviceCharge > 0) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(l10n.serviceCharge, Formatters.number(sale.serviceCharge, decimalPlaces: 2), fontSize: bodyFontSize),
              ],
              if (showCostPrice) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(l10n.costPrice, Formatters.number(totalCost, decimalPlaces: 2), fontSize: smallFontSize, color: PdfColors.grey700),
              ],
              if (showProfit) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(l10n.merchantProfit, Formatters.number(totalMerchantProfit, decimalPlaces: 2), fontSize: smallFontSize, color: PdfColors.grey700),
              ],

              // ── 6. PROMINENT GRAND TOTAL BOX WITH DASHED BORDERS ──
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 2.0),
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 1.0),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(style: pw.BorderStyle.dashed, width: 1.2, color: PdfColors.black),
                    bottom: pw.BorderSide(style: pw.BorderStyle.dashed, width: 1.2, color: PdfColors.black),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      l10n.grandTotal,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalFontSize),
                    ),
                    pw.Text(
                      Formatters.number(sale.total, decimalPlaces: 2),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalFontSize),
                    ),
                  ],
                ),
              ),

              // ── 7. PAYMENT DETAILS ──
              if (showPaymentDetails) ...[
                pw.SizedBox(height: 1.0),
                buildSummaryRow(
                  '${l10n.cash} :',
                  sale.paymentMethod.toLowerCase() == 'cash'
                      ? Formatters.number(effectiveCashReceived ?? sale.total, decimalPlaces: 2)
                      : '0.00',
                  fontSize: bodyFontSize,
                ),
                pw.SizedBox(height: 1.0),
                buildSummaryRow(
                  '${l10n.card} :',
                  sale.paymentMethod.toLowerCase() == 'card'
                      ? Formatters.number(sale.total, decimalPlaces: 2)
                      : '0.00',
                  fontSize: bodyFontSize,
                ),
                pw.SizedBox(height: 1.0),
                buildSummaryRow(
                  '${l10n.remainingAmount} :',
                  Formatters.number(effectiveChange ?? 0.0, decimalPlaces: 2),
                  fontSize: bodyFontSize,
                  isBold: true,
                ),
              ],
              pw.SizedBox(height: 1.0),
              buildSummaryRow(
                '${l10n.itemsCount} :',
                '${items.length}',
                fontSize: bodyFontSize,
                isBold: true,
              ),
              buildDashedDivider(height: 4, thickness: 0.8),

              // ── 9. FOOTER & BARCODE ──
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  footer,
                  style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.15, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Center(
                child: pw.Text(
                  'QuickBill POS',
                  style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (showBarcode) ...[
                pw.SizedBox(height: 3),
                pw.Builder(
                  builder: (context) {
                    try {
                      return pw.Center(
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: sale.billNumber,
                          width: is58mm ? 105 : 135,
                          height: is58mm ? 22 : 26,
                          drawText: true,
                          textStyle: pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontSize: smallFontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      );
                    } catch (_) {
                      return pw.Center(
                        child: pw.Text(
                          '* ${sale.billNumber} *',
                          style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold),
                        ),
                      );
                    }
                  },
                ),
              ],
              pw.SizedBox(height: 2),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// ─────────────────────────────────────────────────────────────
  /// TEMPLATE 1: QUICKBILL CLASSIC RECEIPT (Original 4-Column Design)
  /// ─────────────────────────────────────────────────────────────
  Future<pw.Document> _buildClassicReceipt(
    Sale sale,
    List<SaleItem> items, {
    AppSettings? settings,
    String? overridePaperSize,
    double? cashReceived,
    double? change,
  }) async {
    final doc = pw.Document();
    final l10n = ReceiptL10n.of(settings?.receiptLanguage ?? 'si');

    final shopName = (settings?.shopName.isNotEmpty == true ? settings!.shopName : 'QUICKBILL STORE').toUpperCase();
    final shopAddress = settings?.shopAddress ?? '';
    final shopPhone = settings?.shopPhone ?? '';
    final footer = settings?.receiptFooter.isNotEmpty == true 
        ? settings!.receiptFooter 
        : l10n.thankYou;
    final shopLogoUrl = settings?.shopLogoUrl;

    // Configurable field visibility toggles
    final showLogo = settings?.showReceiptLogo ?? true;
    final showBarcode = settings?.showReceiptBarcode ?? true;
    final showTax = settings?.showReceiptTax ?? true;
    final showPaymentDetails = settings?.showReceiptPaymentDetails ?? true;
    final showCashier = settings?.showReceiptCashier ?? true;
    final showCustomer = settings?.showReceiptCustomer ?? true;
    final showProfit = settings?.showReceiptProfit ?? false;
    final showCostPrice = settings?.showReceiptCostPrice ?? false;

    final bool is58mm = overridePaperSize == '58mm' || (overridePaperSize == null && (settings?.is58mm ?? false));
    final double pageWidth = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;

    // Typography sizing calibrated for high-density retail thermal printing
    final double titleFontSize = is58mm ? 11.5 : 14.5;
    final double headerFontSize = is58mm ? 7.0 : 8.5;
    final double bodyFontSize = is58mm ? 7.0 : 8.2;
    final double smallFontSize = is58mm ? 6.0 : 7.0;
    final double totalFontSize = is58mm ? 11.5 : 14.0;

    // Column widths for 4-column item table (ITEM, QTY, PRICE, TOTAL)
    final double qtyColWidth = is58mm ? 22.0 : 30.0;
    final double priceColWidth = is58mm ? 30.0 : 40.0;
    final double amountColWidth = is58mm ? 34.0 : 44.0;

    // Parse effective cash received & change from arguments or sale.notes
    double? effectiveCashReceived = cashReceived;
    double? effectiveChange = change;

    if (effectiveCashReceived == null && sale.paymentMethod.toLowerCase() == 'cash' && sale.notes != null) {
      final cashMatch = RegExp(r'(?:Cash|Received):\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (cashMatch != null) {
        effectiveCashReceived = double.tryParse(cashMatch.group(1)!);
      }
      final changeMatch = RegExp(r'Change:\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (changeMatch != null) {
        effectiveChange = double.tryParse(changeMatch.group(1)!);
      }
    }
    if (effectiveCashReceived != null && effectiveChange == null) {
      effectiveChange = (effectiveCashReceived - sale.total).clamp(0.0, double.infinity);
    }

    String formatQty(SaleItem item) {
      final qty = item.soldQuantity ?? item.quantity;
      final numStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
      if (item.soldUnit != null && item.soldUnit!.isNotEmpty && item.soldUnit != 'pcs' && item.soldUnit != 'piece') {
        return '$numStr${item.soldUnit}';
      }
      return numStr;
    }

    String totalPieces(List<SaleItem> itemsList) {
      double sum = 0;
      for (final i in itemsList) {
        sum += (i.soldQuantity ?? i.quantity);
      }
      return sum == sum.roundToDouble() ? sum.toInt().toString() : sum.toStringAsFixed(1);
    }

    final double subtotalGross = items.fold(0.0, (sum, item) => sum + item.total + item.discount);
    final double totalItemDiscounts = items.fold(0.0, (sum, item) => sum + item.discount);
    final double totalDiscount = totalItemDiscounts + sale.discount;
    final double totalCost = items.fold(0.0, (sum, i) => sum + (i.costPrice * i.quantity));
    final double totalProfit = items.fold(0.0, (sum, i) => sum + (i.total - (i.costPrice * i.quantity))) - sale.discount;
    final double remainingAmt = (effectiveCashReceived != null && effectiveCashReceived < sale.total)
        ? (sale.total - effectiveCashReceived).clamp(0.0, double.infinity)
        : (sale.paymentMethod.toLowerCase() == 'credit' ? sale.total : 0.0);

    // Accurate thermal receipt height calculation
    final double headerHeightMm = (showLogo && shopLogoUrl != null && shopLogoUrl.isNotEmpty ? (is58mm ? 18.0 : 24.0) : 0.0)
        + 8.0 // Store name
        + (shopAddress.isNotEmpty ? 5.0 : 0.0)
        + (shopPhone.isNotEmpty ? 4.5 : 0.0)
        + (showCustomer && sale.customerName?.isNotEmpty == true ? 15.0 : 11.0);
    
    const double tableHeaderHeightMm = 6.0;

    double itemsHeightMm = 0.0;
    for (final item in items) {
      final int nameCharsPerLine = is58mm ? 15 : 24;
      final int nameLines = (item.productName.length / nameCharsPerLine).ceil().clamp(1, 4);
      itemsHeightMm += (nameLines * 3.6) + 2.0;
      if (item.discount > 0) itemsHeightMm += 3.2;
    }

    final double summaryHeightMm = 7.0 // Subtotal & Items count
        + (totalDiscount > 0 ? 4.5 : 0.0)
        + (showTax && sale.tax > 0 ? 4.5 : 0.0)
        + (sale.serviceCharge > 0 ? 4.5 : 0.0)
        + (showCostPrice ? 4.5 : 0.0)
        + (showProfit ? 4.5 : 0.0)
        + 11.0 // TOTAL box
        + (showPaymentDetails ? 5.0 : 0.0)
        + (showPaymentDetails && sale.paymentMethod.toLowerCase() == 'cash' && effectiveCashReceived != null ? 9.0 : 0.0)
        + (remainingAmt > 0 ? 4.5 : 0.0);

    final double footerHeightMm = 11.0 // Thank you & Powered by
        + (showBarcode ? (is58mm ? 14.0 : 16.0) : 0.0);

    final double totalHeightMm = headerHeightMm + tableHeaderHeightMm + itemsHeightMm + summaryHeightMm + footerHeightMm + 8.0;
    final double pageHeight = totalHeightMm * PdfPageFormat.mm;

    final pageMargin = is58mm 
        ? const pw.EdgeInsets.symmetric(horizontal: 3.0, vertical: 3.5)
        : const pw.EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0);

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginTop: pageMargin.top,
      marginBottom: pageMargin.bottom,
      marginLeft: pageMargin.left,
      marginRight: pageMargin.right,
    );

    pw.ImageProvider? logoImage;
    if (showLogo && shopLogoUrl != null && shopLogoUrl.isNotEmpty) {
      try {
        logoImage = await networkImage(shopLogoUrl);
      } catch (e) {
        debugPrint('Error loading shop logo for receipt: $e');
      }
    }

    doc.addPage(
      pw.Page(
        theme: await _getTheme(),
        pageFormat: pageFormat,
        margin: pageMargin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── 1. STORE LOGO & HEADER ──
              if (logoImage != null)
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3.0),
                    child: pw.Image(
                      logoImage,
                      width: is58mm ? 36 : 50,
                      height: is58mm ? 26 : 36,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  shopName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleFontSize, lineSpacing: 1.05),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (shopAddress.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Center(
                    child: pw.Text(
                      shopAddress,
                      style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.05),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              if (shopPhone.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.0),
                  child: pw.Center(
                    child: pw.Text(
                      '${l10n.phone}: $shopPhone',
                      style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.05),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.6, height: 4),

              // ── 2. METADATA BLOCK ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${l10n.billNo}: ${sale.billNumber}', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt), style: pw.TextStyle(fontSize: bodyFontSize)),
                ],
              ),
              pw.SizedBox(height: 1.0),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (showCashier)
                    pw.Text('${l10n.cashier}: ${sale.cashierName?.isNotEmpty == true ? sale.cashierName : "Admin"}', style: pw.TextStyle(fontSize: bodyFontSize))
                  else
                    pw.SizedBox(),
                  if (showCustomer && sale.customerName != null && sale.customerName!.isNotEmpty)
                    pw.Text('${l10n.customer}: ${sale.customerName}', style: pw.TextStyle(fontSize: bodyFontSize)),
                ],
              ),
              if (showCustomer && sale.customerPhone != null && sale.customerPhone!.isNotEmpty && (sale.customerName == null || sale.customerName!.isEmpty))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.0),
                  child: pw.Text('${l10n.phone}: ${sale.customerPhone}', style: pw.TextStyle(fontSize: smallFontSize)),
                ),
              pw.Divider(thickness: 0.6, height: 4),

              // ── 3. 4-COLUMN ITEM TABLE HEADER ──
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      l10n.itemHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(
                    width: qtyColWidth,
                    child: pw.Text(
                      l10n.qtyHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: priceColWidth,
                    child: pw.Text(
                      l10n.priceHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: amountColWidth,
                    child: pw.Text(
                      l10n.totalHeader,
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5, height: 3),

              // ── 4. TABLE ITEMS ──
              for (final item in items)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.15),
                            ),
                          ),
                          pw.SizedBox(
                            width: qtyColWidth,
                            child: pw.Text(
                              formatQty(item),
                              style: pw.TextStyle(fontSize: bodyFontSize),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(
                            width: priceColWidth,
                            child: pw.Text(
                              Formatters.number(item.unitPrice, decimalPlaces: 2),
                              style: pw.TextStyle(fontSize: bodyFontSize),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(
                            width: amountColWidth,
                            child: pw.Text(
                              Formatters.number(item.total + item.discount, decimalPlaces: 2),
                              style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      if (item.discount > 0)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 0.8),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '  (${l10n.discount}:',
                                style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                              ),
                              pw.Text(
                                '-${Formatters.number(item.discount, decimalPlaces: 2)} | ${l10n.totalHeader}: ${Formatters.number(item.total, decimalPlaces: 2)})',
                                style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              pw.Divider(thickness: 0.6, height: 4),

              // ── 5. SUBTOTAL & DISCOUNTS ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${l10n.itemsCount}: ${items.length} (${l10n.piecesShort}: ${totalPieces(items)})',
                    style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey800),
                  ),
                  pw.Row(
                    children: [
                      pw.Text('${l10n.subtotal}: ', style: pw.TextStyle(fontSize: bodyFontSize)),
                      pw.Text(
                        Formatters.number(subtotalGross, decimalPlaces: 2),
                        style: pw.TextStyle(fontSize: bodyFontSize),
                      ),
                    ],
                  ),
                ],
              ),
              if (totalDiscount > 0) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l10n.discount}:', style: pw.TextStyle(fontSize: bodyFontSize)),
                    pw.Text(
                      '-${Formatters.number(totalDiscount, decimalPlaces: 2)}',
                      style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
              if (showTax && sale.tax > 0) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l10n.tax}:', style: pw.TextStyle(fontSize: bodyFontSize)),
                    pw.Text(
                      Formatters.number(sale.tax, decimalPlaces: 2),
                      style: pw.TextStyle(fontSize: bodyFontSize),
                    ),
                  ],
                ),
              ],
              if (sale.serviceCharge > 0) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l10n.serviceCharge}:', style: pw.TextStyle(fontSize: bodyFontSize)),
                    pw.Text(
                      Formatters.number(sale.serviceCharge, decimalPlaces: 2),
                      style: pw.TextStyle(fontSize: bodyFontSize),
                    ),
                  ],
                ),
              ],
              if (showCostPrice) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(l10n.costPrice, style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700)),
                    pw.Text(Formatters.number(totalCost, decimalPlaces: 2), style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700)),
                  ],
                ),
              ],
              if (showProfit) ...[
                pw.SizedBox(height: 1.0),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(l10n.merchantProfit, style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700)),
                    pw.Text(Formatters.number(totalProfit, decimalPlaces: 2), style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700)),
                  ],
                ),
              ],

              // ── 6. PROMINENT TOTAL BOX ──
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 3.0),
                padding: const pw.EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 1.2, color: PdfColors.black),
                    bottom: pw.BorderSide(width: 1.2, color: PdfColors.black),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      l10n.grandTotal,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalFontSize),
                    ),
                    pw.Text(
                      Formatters.currency(sale.total),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalFontSize),
                    ),
                  ],
                ),
              ),

              // ── 7. PAYMENT METHOD & CASH BREAKDOWN ──
              if (showPaymentDetails) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${l10n.paymentMethod}:', style: pw.TextStyle(fontSize: bodyFontSize)),
                    pw.Text(
                      sale.paymentMethod.toUpperCase(),
                      style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                if (sale.paymentMethod.toLowerCase() == 'cash' && effectiveCashReceived != null) ...[
                  pw.SizedBox(height: 1.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${l10n.cashReceived}:', style: pw.TextStyle(fontSize: bodyFontSize)),
                      pw.Text(
                        Formatters.number(effectiveCashReceived, decimalPlaces: 2),
                        style: pw.TextStyle(fontSize: bodyFontSize),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 1.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${l10n.change}:', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        Formatters.number(effectiveChange ?? 0.0, decimalPlaces: 2),
                        style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                if (remainingAmt > 0) ...[
                  pw.SizedBox(height: 1.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${l10n.remainingAmount}:', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        Formatters.number(remainingAmt, decimalPlaces: 2),
                        style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                pw.Divider(thickness: 0.6, height: 4),
              ],

              // ── 8. FOOTER & 1D BARCODE ──
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  footer,
                  style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.15),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Powered by QuickBill POS',
                  style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (showBarcode) ...[
                pw.SizedBox(height: 4),
                pw.Builder(
                  builder: (context) {
                    try {
                      return pw.Center(
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: sale.billNumber,
                          width: is58mm ? 105 : 135,
                          height: is58mm ? 22 : 26,
                          drawText: true,
                          textStyle: pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontSize: smallFontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      );
                    } catch (_) {
                      return pw.Center(
                        child: pw.Text(
                          '* ${sale.billNumber} *',
                          style: pw.TextStyle(fontSize: smallFontSize, fontWeight: pw.FontWeight.bold),
                        ),
                      );
                    }
                  },
                ),
              ],
              pw.SizedBox(height: 2),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// Generate and print/share a sale receipt
  Future<void> generateReceipt(
    Sale sale,
    List<SaleItem> items, {
    AppSettings? settings,
    double? cashReceived,
    double? change,
  }) async {
    final doc = await buildReceiptDocument(
      sale,
      items,
      settings: settings,
      cashReceived: cashReceived,
      change: change,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${sale.billNumber}',
      dynamicLayout: false,
    );
  }

  /// Generate a professional A4 Invoice
  Future<void> generateProfessionalInvoice(Sale sale, List<SaleItem> items, {AppSettings? settings}) async {
    final doc = pw.Document();
    final shopName = settings?.shopName ?? 'QUICKBILL POS';
    final shopAddress = settings?.shopAddress ?? '123 Business Street, Colombo';
    final shopPhone = settings?.shopPhone ?? '${globalAppRegion.phonePrefix} 11 234 5678';
    final footer = settings?.receiptFooter ?? 'Thank you for your business!';
    final shopLogoUrl = settings?.shopLogoUrl;

    pw.ImageProvider? logoImage;
    if (shopLogoUrl != null) {
      try {
        logoImage = await networkImage(shopLogoUrl);
      } catch (e) {
        debugPrint('Error loading shop logo for invoice: $e');
      }
    }

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 16),
                        child: pw.Image(logoImage, width: 60, height: 60, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                        pw.SizedBox(height: 4),
                        pw.Text(shopAddress),
                        pw.Text('Tel: $shopPhone'),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 8),
                    pw.Text('Invoice #: ${sale.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormat('dd MMM yyyy').format(sale.createdAt)}'),
                    if (sale.cashierName != null && sale.cashierName!.isNotEmpty) pw.Text('Cashier: ${sale.cashierName}'),
                    pw.Text('Time: ${DateFormat('HH:mm').format(sale.createdAt)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // Customer Info (if available)
            if (sale.customerName != null) ...[
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(sale.customerName!, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 30),
            ],

            // Items Table
            // Items Table
            pw.Builder(
              builder: (context) {
                final bool hasItemDiscounts = items.any((item) => item.discount > 0);
                
                return pw.TableHelper.fromTextArray(
                  border: null,
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey900),
                  headerHeight: 30,
                  cellHeight: 25,
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  headers: hasItemDiscounts 
                    ? ['Description', 'Qty', 'Unit Price', 'Discount', 'Total']
                    : ['Description', 'Qty', 'Unit Price', 'Total'],
                  data: items.map((item) => hasItemDiscounts 
                    ? [
                        item.productName,
                        item.quantity.toString(),
                        Formatters.currencySimple(item.unitPrice),
                        item.discount > 0 ? Formatters.currencySimple(item.discount) : '-',
                        Formatters.currencySimple(item.total),
                      ]
                    : [
                        item.productName,
                        item.quantity.toString(),
                        Formatters.currencySimple(item.unitPrice),
                        Formatters.currencySimple(item.total),
                      ]).toList(),
                  columnWidths: hasItemDiscounts
                    ? {
                        0: const pw.FlexColumnWidth(3.5),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1.5),
                        3: const pw.FlexColumnWidth(1.5),
                        4: const pw.FlexColumnWidth(2),
                      }
                    : {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                      },
                  cellAlignments: hasItemDiscounts
                    ? {
                        1: pw.Alignment.center,
                        2: pw.Alignment.centerRight,
                        3: pw.Alignment.centerRight,
                        4: pw.Alignment.centerRight,
                      }
                    : {
                        1: pw.Alignment.center,
                        2: pw.Alignment.centerRight,
                        3: pw.Alignment.centerRight,
                      },
                );
              }
            ),

            pw.SizedBox(height: 30),

            // Totals Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Subtotal: ', style: const pw.TextStyle(fontSize: 14)),
                        pw.SizedBox(width: 40),
                        pw.Text(Formatters.currency(sale.total + sale.discount + items.fold(0.0, (sum, item) => sum + item.discount)), style: const pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (items.any((item) => item.discount > 0)) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text('Item Discounts: ', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                          pw.SizedBox(width: 40),
                          pw.Text('-${Formatters.currency(items.fold(0.0, (sum, item) => sum + item.discount))}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                    if (sale.discount > 0) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text('Bill Discount: ', style: const pw.TextStyle(fontSize: 14, color: PdfColors.red)),
                          pw.SizedBox(width: 40),
                          pw.Text('-${Formatters.currency(sale.discount)}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.red)),
                        ],
                      ),
                    ],
                    pw.Divider(color: PdfColors.grey900, thickness: 2, height: 20),
                    pw.Row(
                      children: [
                        pw.Text('TOTAL: ', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                        pw.SizedBox(width: 40),
                        pw.Text(Formatters.currency(sale.total), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Payment Method: ${sale.paymentMethod.toUpperCase()}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 60),

            // Footer
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(footer, style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Text('Powered by QuickBill POS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Invoice_${sale.billNumber}',
      dynamicLayout: false,
    );
  }

  /// Generate and share Stock Report
  Future<void> generateStockReport(List<Product> products, {AppSettings? settings, String Function(String)? localizeCategory}) async {
    final doc = pw.Document();
    final shopName = settings?.shopName ?? 'QuickBill Store';

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('Stock Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                  ],
                ),
                pw.Text(Formatters.fullDate(DateTime.now())),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Stock', 'Category', 'Price', 'Value'],
            data: products.map((p) => [
              p.name,
              '${p.calculatedStock} ${p.unit}',
              p.category != null ? (localizeCategory?.call(p.category!) ?? p.category!) : '-',
              Formatters.currency(p.price),
              Formatters.currency(p.price * p.calculatedStock)
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'stock_report.pdf');
  }

  /// Generate and share Sales Report for a period
  Future<void> generateSalesReport(List<Sale> sales, DateTime start, DateTime end, {AppSettings? settings}) async {
    final doc = pw.Document();
    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.total);
    final totalDiscounts = sales.fold(0.0, (sum, s) => sum + s.discount);
    final shopName = settings?.shopName ?? 'QuickBill Store';

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text('SALES REPORT', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                  pw.SizedBox(height: 4),
                  pw.Text('Period: ${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated on:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Summary Cards
          pw.Row(
            children: [
              _buildMetricCard('TOTAL REVENUE', Formatters.currency(totalRevenue), PdfColors.grey900),
              pw.SizedBox(width: 16),
              _buildMetricCard('TRANSACTIONS', sales.length.toString(), PdfColors.grey700),
              pw.SizedBox(width: 16),
              _buildMetricCard('DISCOUNTS', Formatters.currency(totalDiscounts), PdfColors.orange900),
            ],
          ),
          pw.SizedBox(height: 30),
          
          // Sales Table
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey900),
            headerHeight: 25,
            cellHeight: 25,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            headers: ['Date', 'Bill #', 'Customer', 'Items', 'Payment', 'Total'],
            data: sales.map((s) {
              final itemsSummary = s.items.length == 1 
                  ? s.items.first.productName 
                  : '${s.items.first.productName} +${s.items.length - 1} more';
              return [
                DateFormat('dd/MM HH:mm').format(s.createdAt),
                s.billNumber,
                s.customerName ?? '-',
                itemsSummary,
                s.paymentMethod.toUpperCase(),
                Formatters.currency(s.total)
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1.5),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
            child: pw.Text('End of Report • Powered by QuickBill POS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'sales_report_${DateFormat('yyyyMMdd').format(start)}.pdf');
  }

  pw.Widget _buildMetricCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// Generate and share Refund Report
  Future<void> generateRefundReport(List<Map<String, dynamic>> refunds, DateTime start, DateTime end, {AppSettings? settings}) async {
    final doc = pw.Document();
    final totalRefunded = refunds.fold(0.0, (sum, r) => sum + (r['refund_amount'] as num).toDouble());
    final shopName = settings?.shopName ?? 'QuickBill Store';

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text('Refund Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ],
                    ),
                    pw.Text('Generated: ${Formatters.fullDate(DateTime.now())}'),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text('Period: ${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}'),
                pw.Divider(thickness: 2, color: PdfColors.redAccent),
              ],
            ),
          ),
          
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Bill #', 'Items Returned', 'Reason', 'Total'],
            data: refunds.map((r) {
              final items = (r['items'] as List?) ?? [];
              final itemsText = items.map((i) => 
                '${Formatters.quantity(i['quantity'])} ${i['product_name']} (${i['condition'] == 'restockable' ? 'Stock' : 'Damaged'})'
              ).join('\n');

              return [
                DateFormat('dd/MM HH:mm').format(DateTime.parse(r['return_date'])),
                r['bill_number'],
                itemsText,
                r['reason'] ?? '-',
                Formatters.currency(r['refund_amount'])
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.2),
            },
            cellAlignments: {
              4: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Refund Transactions: ${refunds.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Refunded Amount: ${Formatters.currency(totalRefunded)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'refund_report.pdf');
  }

  /// Generate and share Damage & Waste Report
  Future<void> generateDamageReportPdf(List<Map<String, dynamic>> items, DateTime start, DateTime end) async {
    final doc = pw.Document();
    
    // Calculate total
    final double totalValue = items.fold(0.0, (sum, i) => sum + (i['cost_value'] as num).toDouble());

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Damage & Waste Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange800)),
                      ],
                    ),
                    pw.Text('Generated: ${Formatters.fullDate(DateTime.now())}'),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text('Period: ${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}'),
                pw.Divider(thickness: 2, color: PdfColors.deepOrangeAccent),
              ],
            ),
          ),
          
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Date', 'Product', 'Qty', 'Reason', 'Cost'],
            data: items.map((r) {
              final isWriteOff = r['source'] == 'write_off';
              return [
                isWriteOff ? 'Manual Write-off' : 'Customer Return (Damaged)',
                DateFormat('dd/MM HH:mm').format(DateTime.parse(r['date'])),
                r['product_name'],
                Formatters.quantity(r['quantity']),
                r['reason'] ?? '-',
                Formatters.currency(r['cost_value'])
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.deepOrange800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.2),
            },
            cellAlignments: {
              3: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Items: ${items.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Value Lost: ${Formatters.currency(totalValue)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange800)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'damage_waste_report.pdf');
  }

  /// Generate and share Supplier Returns Report
  Future<void> generateSupplierReturnsReportPdf(List<Map<String, dynamic>> items, DateTime start, DateTime end) async {
    final doc = pw.Document();
    
    // Calculate total
    final double totalValue = items.fold(0.0, (sum, i) => sum + (i['cost_value'] as num).toDouble());

    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Supplier Returns Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      ],
                    ),
                    pw.Text('Generated: ${Formatters.fullDate(DateTime.now())}'),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text('Period: ${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}'),
                pw.Divider(thickness: 2, color: PdfColors.blueAccent),
              ],
            ),
          ),
          
          pw.TableHelper.fromTextArray(
            headers: ['Type', 'Date', 'Product', 'Qty', 'Reason', 'Cost'],
            data: items.map((r) {
              return [
                'Supplier Return',
                DateFormat('dd/MM HH:mm').format(DateTime.parse(r['date'])),
                r['product_name'],
                Formatters.quantity(r['quantity']),
                r['reason'] ?? '-',
                Formatters.currency(r['cost_value'])
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.2),
            },
            cellAlignments: {
              3: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Items: ${items.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Value Returned: ${Formatters.currency(totalValue)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'supplier_returns_report.pdf');
  }

  /// Generate and share Purchase Order
  Future<void> generatePurchaseOrder(Purchase purchase, {AppSettings? settings, String? supplierName}) async {
    final doc = pw.Document();
    final shopName = settings?.shopName ?? 'QUICKBILL STORE';
    final shopAddress = settings?.shopAddress ?? '123 Business Street, Colombo';
    final shopPhone = settings?.shopPhone ?? '${globalAppRegion.phonePrefix} 11 234 5678';
    
    doc.addPage(
      pw.MultiPage(
        theme: await _getTheme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                    pw.SizedBox(height: 4),
                    pw.Text(shopAddress),
                    pw.Text('Tel: $shopPhone'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 8),
                    pw.Text('PO #: ${purchase.id ?? "DRAFT"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormat('dd MMM yyyy').format(purchase.date)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // Vendor Info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              width: double.infinity,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('VENDOR:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(supplierName ?? 'Unknown Supplier', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items Table
            pw.TableHelper.fromTextArray(
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerHeight: 30,
              cellHeight: 25,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              headers: ['Product', 'Quantity', 'Unit Price', 'Total'],
              data: purchase.items.map((item) => [
                item.productName,
                Formatters.quantity(item.quantity),
                Formatters.currencySimple(item.costPrice),
                Formatters.currencySimple(item.quantity * item.costPrice),
              ]).toList(),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),

            pw.SizedBox(height: 20),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('TOTAL: ', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 40),
                        pw.Text(Formatters.currency(purchase.totalAmount), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
            pw.SizedBox(height: 40),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'PO_${purchase.id}.pdf');
  }
}

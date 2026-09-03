import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/region_utils.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../utils/formatters.dart';
import '../providers/preference_provider.dart';

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

    pw.Font? baseFont;
    pw.Font? boldFont;
    pw.Font? sinhalaFont;

    // 1. Try loading from bundled assets first (100% offline guarantee)
    try {
      final sinhalaData = await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
      sinhalaFont = pw.Font.ttf(sinhalaData);
    } catch (e) {
      debugPrint('Note: Local Sinhala font asset load error: $e');
    }

    try {
      final baseData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      baseFont = pw.Font.ttf(baseData);
    } catch (e) {
      debugPrint('Note: Local base font asset load error: $e');
    }

    try {
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('Note: Local bold font asset load error: $e');
    }

    // 2. Fallback to PdfGoogleFonts if assets are missing
    baseFont ??= await _tryGoogleFont(PdfGoogleFonts.notoSansRegular) ?? pw.Font.helvetica();
    boldFont ??= await _tryGoogleFont(PdfGoogleFonts.notoSansBold) ?? pw.Font.helveticaBold();
    sinhalaFont ??= await _tryGoogleFont(PdfGoogleFonts.notoSansSinhalaRegular);

    final fontFallbacks = <pw.Font>[];
    if (sinhalaFont != null) {
      fontFallbacks.add(sinhalaFont);
    }

    try {
      _theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: baseFont,
        boldItalic: boldFont,
        fontFallback: fontFallbacks,
      );
    } catch (e) {
      debugPrint('Error creating PDF theme: $e');
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
  }) async {
    final doc = pw.Document();
    final shopName = settings?.shopName ?? 'QUICKBILL STORE';
    final shopAddress = settings?.shopAddress ?? '';
    final shopPhone = settings?.shopPhone ?? '';
    final footer = settings?.receiptFooter.isNotEmpty == true 
        ? settings!.receiptFooter 
        : 'ස්තුතියි! නැවත එන්න! / Thank you for shopping!';
    final shopLogoUrl = settings?.shopLogoUrl;

    final bool is58mm = overridePaperSize == '58mm' || (overridePaperSize == null && (settings?.is58mm ?? false));
    final double pageWidth = (is58mm ? 58.0 : 80.0) * PdfPageFormat.mm;

    // Typography sizing adapted for thermal print clarity
    final double titleFontSize = is58mm ? 12.0 : 15.0;
    final double headerFontSize = is58mm ? 7.0 : 8.5;
    final double bodyFontSize = is58mm ? 7.5 : 9.0;
    final double smallFontSize = is58mm ? 6.5 : 7.5;
    final double totalLabelSize = is58mm ? 9.5 : 11.5;
    final double totalFontSize = is58mm ? 11.5 : 14.0;

    // Column widths for thermal receipts
    final double qtyColWidth = is58mm ? 36.0 : 48.0;
    final double amountColWidth = is58mm ? 48.0 : 64.0;

    // Accurate thermal receipt height calculation (removes trailing blank paper)
    final double headerHeightMm = (shopLogoUrl != null ? 35.0 : 0.0) 
        + 18.0 // Shop name & padding
        + (shopAddress.isNotEmpty ? 8.0 : 0.0) 
        + (shopPhone.isNotEmpty ? 8.0 : 0.0)
        + 30.0; // Bill No, Date, Cashier, Customer info

    final double tableHeaderHeightMm = 12.0;
    
    // Calculate per-item height based on name length & discounts
    double itemsHeightMm = 0.0;
    for (final item in items) {
      final int nameLines = (item.productName.length / (is58mm ? 16 : 24)).ceil();
      itemsHeightMm += (nameLines * 5.0) + 4.0;
      if (item.discount > 0) itemsHeightMm += 5.0;
    }

    final double summaryHeightMm = (items.any((i) => i.discount > 0) || sale.discount > 0 ? 18.0 : 0.0) 
        + 24.0 // Total box & payment method
        + 18.0; // Footer thank you & QuickBill badge

    final double totalHeightMm = headerHeightMm + tableHeaderHeightMm + itemsHeightMm + summaryHeightMm + 6.0;
    final double pageHeight = totalHeightMm * PdfPageFormat.mm;

    final pageMargin = is58mm 
        ? const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 4)
        : const pw.EdgeInsets.symmetric(horizontal: 6.0, vertical: 6);

    final pageFormat = PdfPageFormat(
      pageWidth,
      pageHeight,
      marginTop: pageMargin.top,
      marginBottom: pageMargin.bottom,
      marginLeft: pageMargin.left,
      marginRight: pageMargin.right,
    );

    pw.ImageProvider? logoImage;
    if (shopLogoUrl != null) {
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
              // ── SHOP LOGO & HEADER ──
              if (logoImage != null)
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Image(
                      logoImage,
                      width: is58mm ? 42 : 65,
                      height: is58mm ? 36 : 55,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  shopName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleFontSize, lineSpacing: 1.1),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (shopAddress.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Center(
                    child: pw.Text(
                      shopAddress,
                      style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              if (shopPhone.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.0),
                  child: pw.Center(
                    child: pw.Text(
                      'දු.ක / Tel: $shopPhone',
                      style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              pw.SizedBox(height: is58mm ? 3 : 5),
              pw.Divider(thickness: 0.8),
              
              // ── BILINGUAL METADATA ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('බිල් අංකය / Bill No:', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                  pw.Text(sale.billNumber, style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 1.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('දිනය / Date:', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                  pw.Text(Formatters.fullDate(sale.createdAt), style: pw.TextStyle(fontSize: bodyFontSize)),
                ],
              ),
              if (sale.cashierName != null && sale.cashierName!.isNotEmpty) ...[
                pw.SizedBox(height: 1.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('කැෂියර් / Cashier:', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                    pw.Text('${sale.cashierName}', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                pw.SizedBox(height: 1.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('පාරිභෝගිකයා / Customer:', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                    pw.Text('${sale.customerName}', style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.8),

              // ── STRUCTURED 3-COLUMN TABLE HEADER ──
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: is58mm ? 5 : 6,
                    child: pw.Text(
                      'භාණ්ඩය / Item',
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold, lineSpacing: 1.1),
                    ),
                  ),
                  pw.SizedBox(
                    width: qtyColWidth,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: amountColWidth,
                    child: pw.Text(
                      'මුදල / Amount',
                      style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold, lineSpacing: 1.1),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // ── TABLE ITEMS WITH SINHALA & UNIT FORMATTING ──
              for (final item in items)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: is58mm ? 5 : 6,
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.25),
                            ),
                          ),
                          pw.SizedBox(
                            width: qtyColWidth,
                            child: pw.Text(
                              item.formattedQuantity,
                              style: pw.TextStyle(fontSize: bodyFontSize),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(
                            width: amountColWidth,
                            child: pw.Text(
                              Formatters.currency(item.total + item.discount),
                              style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      if (item.discount > 0) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 1.0, left: 3.0),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '↳ වට්ටම් / Disc.',
                                style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700, lineSpacing: 1.1),
                              ),
                              pw.Text(
                                '-${Formatters.currency(item.discount)} (Net: ${Formatters.currency(item.total)})',
                                style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              pw.Divider(thickness: 0.8),
              
              // ── SUB-TOTAL & DISCOUNTS (IF APPLICABLE) ──
              if (items.any((item) => item.discount > 0) || sale.discount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('උප එකතුව / Subtotal', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                    pw.Text(
                      Formatters.currency(sale.total + sale.discount + items.fold(0.0, (sum, item) => sum + item.discount)),
                      style: pw.TextStyle(fontSize: bodyFontSize),
                    ),
                  ],
                ),
                if (items.any((item) => item.discount > 0)) ...[
                  pw.SizedBox(height: 1.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('භාණ්ඩ වට්ටම් / Item Disc.', style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.1)),
                      pw.Text(
                        '-${Formatters.currency(items.fold(0.0, (sum, item) => sum + item.discount))}',
                        style: pw.TextStyle(fontSize: smallFontSize),
                      ),
                    ],
                  ),
                ],
                if (sale.discount > 0) ...[
                  pw.SizedBox(height: 1.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('බිල්පත් වට්ටම් / Bill Disc.', style: pw.TextStyle(fontSize: smallFontSize, lineSpacing: 1.1)),
                      pw.Text(
                        '-${Formatters.currency(sale.discount)}',
                        style: pw.TextStyle(fontSize: smallFontSize),
                      ),
                    ],
                  ),
                ],
                pw.SizedBox(height: 2),
              ],
              
              // ── HIGH-CONTRAST TOTAL SECTION (NO COLLISION) ──
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 3.0),
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 2.0),
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
                      'මුළු එකතුව / TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalLabelSize, lineSpacing: 1.1),
                    ),
                    pw.Text(
                      Formatters.currency(sale.total),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: totalFontSize),
                    ),
                  ],
                ),
              ),

              // ── PAYMENT METHOD ──
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ගෙවීම් ක්‍රමය / Payment:', style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.1)),
                  pw.Text(
                    sale.paymentMethod.toUpperCase(),
                    style: pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: is58mm ? 4 : 6),

              // ── FOOTER & POWERED BY ──
              pw.Center(
                child: pw.Text(
                  footer,
                  style: pw.TextStyle(fontSize: bodyFontSize, lineSpacing: 1.2),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'Powered by QuickBill POS',
                  style: pw.TextStyle(fontSize: smallFontSize, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  /// Generate and print/share a sale receipt
  Future<void> generateReceipt(Sale sale, List<SaleItem> items, {AppSettings? settings}) async {
    final doc = await buildReceiptDocument(sale, items, settings: settings);

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

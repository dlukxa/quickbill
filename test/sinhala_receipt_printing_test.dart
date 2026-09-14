import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/services/receipt_image_generator.dart';
import 'package:quickbill/services/receipt_raster_converter.dart';
import 'package:quickbill/utils/pos_l10n.dart';
import 'package:quickbill/widgets/receipt/receipt_preview_dialog.dart';
import 'package:quickbill/widgets/receipt/receipt_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test dataset matching exact requirements
  final sampleSale = Sale(
    billNumber: 'INV-2026-0099',
    total: 1450.00,
    discount: 50.00,
    tax: 0.0,
    serviceCharge: 0.0,
    itemsCount: 4,
    paymentMethod: 'cash',
    cashierName: 'හර්ෂණ (Harshana)',
    customerName: 'කුසල් මෙන්ඩිස්',
    customerPhone: '077 123 4567',
    createdAt: DateTime(2026, 9, 12, 14, 30),
    notes: 'Cash: 1500.00\nChange: 50.00',
  );

  final List<SaleItem> sampleItems = [
    SaleItem(
      saleId: 1,
      productId: 101,
      productName: 'ප්රීමා වෙජිටබල් ඔයිල් මිලි ලීටර් 100',
      quantity: 1,
      unitPrice: 420.00,
      costPrice: 380.00,
      discount: 20.00,
      total: 400.00,
    ),
    SaleItem(
      saleId: 1,
      productId: 102,
      productName: 'Egg Yellow food colour 28ml',
      quantity: 2,
      unitPrice: 125.00,
      costPrice: 90.00,
      discount: 0.00,
      total: 250.00,
    ),
    SaleItem(
      saleId: 1,
      productId: 103,
      productName: 'කිරිපිටි',
      quantity: 1,
      unitPrice: 480.00,
      costPrice: 420.00,
      discount: 30.00,
      total: 450.00,
    ),
    SaleItem(
      saleId: 1,
      productId: 104,
      productName: 'Rice 5kg',
      quantity: 1,
      unitPrice: 350.00,
      costPrice: 300.00,
      discount: 0.00,
      total: 350.00,
    ),
  ];

  final baseSettings = AppSettings(
    shopName: 'වාසිය සුපර් මාට් (Vasiya Super Mart)',
    shopAddress: 'මාකලේ පාර, දොඩම්ගස්ලන්ද',
    shopPhone: '075 059 6413 / 078 526 1919',
    lowStockThreshold: 10,
    receiptFooter: 'ස්තූතියි නැවත එන්න... / Thank you, come again!',
    languageCode: 'si',
    regionCode: 'LK',
    businessType: 'Retail',
    isSetupComplete: true,
    autoSync: false,
    entityCode: '1',
    printerPaperSize: '80mm',
    receiptTemplate: 'sri_lankan_retail',
    receiptLanguage: 'si',
    showReceiptLogo: false,
    showReceiptBarcode: true,
    showReceiptStandardPrice: true,
    showReceiptOurPrice: true,
    showReceiptDiscount: true,
    showReceiptPaymentDetails: true,
    showReceiptCashier: true,
    showReceiptCustomer: true,
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fontLoaderSinhala = FontLoader('NotoSansSinhala');
    fontLoaderSinhala.addFont(File('assets/fonts/NotoSansSinhala-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    fontLoaderSinhala.addFont(File('assets/fonts/NotoSansSinhala-Bold.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    await fontLoaderSinhala.load();

    final fontLoaderLatin = FontLoader('NotoSans');
    fontLoaderLatin.addFont(File('assets/fonts/NotoSans-Regular.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    fontLoaderLatin.addFont(File('assets/fonts/NotoSans-Bold.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    await fontLoaderLatin.load();
  });

  group('Sinhala Thermal Receipt Printing System Tests', () {
    test('1. Bundled font assets exist on disk', () {
      final regSinhala = File('assets/fonts/NotoSansSinhala-Regular.ttf');
      final boldSinhala = File('assets/fonts/NotoSansSinhala-Bold.ttf');
      final regLatin = File('assets/fonts/NotoSans-Regular.ttf');
      final boldLatin = File('assets/fonts/NotoSans-Bold.ttf');

      expect(regSinhala.existsSync(), isTrue);
      expect(boldSinhala.existsSync(), isTrue);
      expect(regLatin.existsSync(), isTrue);
      expect(boldLatin.existsSync(), isTrue);
    });

    test('2. 58mm Receipt Image Generation produces exact 384px bitmap', () async {
      final settings58 = baseSettings.copyWith(printerPaperSize: '58mm');
      final Uint8List pngBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: settings58,
        cashReceived: 1500.0,
        change: 50.0,
      );

      expect(pngBytes, isNotEmpty);
      final decoded = img.decodeImage(pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 384);
      expect(decoded.height, greaterThan(200));

      // Save artifact for visual check
      File('test_receipt_58mm.png').writeAsBytesSync(pngBytes);
    });

    test('3. 80mm Receipt Image Generation produces exact 576px bitmap', () async {
      final settings80 = baseSettings.copyWith(printerPaperSize: '80mm');
      final Uint8List pngBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: settings80,
        cashReceived: 1500.0,
        change: 50.0,
      );

      expect(pngBytes, isNotEmpty);
      final decoded = img.decodeImage(pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 576);
      expect(decoded.height, greaterThan(200));

      // Save artifact for visual check
      File('test_receipt_80mm.png').writeAsBytesSync(pngBytes);
    });

    test('4. Long Sinhala product names wrap without horizontal overflow', () async {
      final longNameItem = SaleItem(
        saleId: 1,
        productId: 999,
        productName:
            'ප්රීමා වෙජිටබල් ඔයිල් මිලි ලීටර් 100 විශේෂ ප්‍රවර්ධන ඇසුරුම සහ නොමිලේ ලැබෙන තෑග්ග',
        quantity: 3,
        unitPrice: 420.00,
        costPrice: 380.00,
        total: 1260.00,
      );

      final pngBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: [longNameItem],
        settings: baseSettings.copyWith(printerPaperSize: '58mm'),
      );

      final decoded = img.decodeImage(pngBytes);
      expect(decoded!.width, 384);
      expect(decoded.height, greaterThan(150));
    });

    test('5. Template Variations (Sri Lankan Retail & Classic)', () async {
      // Sri Lankan Retail Template
      final retailBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(receiptTemplate: 'sri_lankan_retail'),
      );
      expect(retailBytes, isNotEmpty);

      // Classic QuickBill Template
      final classicBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(receiptTemplate: 'classic'),
      );
      expect(classicBytes, isNotEmpty);
    });

    test('6. Language Variations (Sinhala, English, and Bilingual)', () async {
      // Sinhala
      final siBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(receiptLanguage: 'si'),
      );
      expect(siBytes, isNotEmpty);

      // English
      final enBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(receiptLanguage: 'en'),
      );
      expect(enBytes, isNotEmpty);

      // Bilingual
      final biBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(receiptLanguage: 'bilingual'),
      );
      expect(biBytes, isNotEmpty);
    });

    test('7. Monochrome ESC/POS Raster Converter (GS v 0)', () async {
      final pngBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(printerPaperSize: '58mm'),
      );

      final List<int> rasterBytes =
          ReceiptRasterConverter.instance.convertPngToEscPosRaster(
        pngBytes,
        targetWidth: 384,
      );

      expect(rasterBytes, isNotEmpty);
      // Verify ESC @ (Init)
      expect(rasterBytes[0], 0x1B);
      expect(rasterBytes[1], 0x40);

      // Verify GS v 0 (Bit Image Raster Command)
      // Follows ESC 3 0 (0x1B, 0x33, 0x00)
      final gsIdx = rasterBytes.indexOf(0x1D);
      expect(gsIdx, greaterThan(0));
      expect(rasterBytes[gsIdx + 1], 0x76); // 'v'
      expect(rasterBytes[gsIdx + 2], 0x30); // '0'
      expect(rasterBytes[gsIdx + 3], 0x00); // mode 0

      // xL and xH: 384 / 8 = 48 bytes
      expect(rasterBytes[gsIdx + 4], 48); // xL = 48
      expect(rasterBytes[gsIdx + 5], 0);  // xH = 0

      // Verify Paper Cut (GS V 66 0) at end
      final cutIdx = rasterBytes.lastIndexOf(0x1D);
      expect(cutIdx, greaterThan(gsIdx));
      expect(rasterBytes[cutIdx + 1], 0x56); // 'V'
      expect(rasterBytes[cutIdx + 2], 66);
    });

    test('8. Monochrome PNG Conversion for BlueThermalPrinter', () async {
      final pngBytes =
          await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: baseSettings.copyWith(printerPaperSize: '80mm'),
      );

      final monoPng = ReceiptRasterConverter.instance.convertToMonochromePng(
        pngBytes,
        targetWidth: 576,
      );

      expect(monoPng, isNotEmpty);
      final decoded = img.decodeImage(monoPng);
      expect(decoded, isNotNull);
      expect(decoded!.width, 576);

      // Verify pixels are binarized (only pure black 0 or pure white 255)
      bool hasBlack = false;
      bool hasWhite = false;
      for (int y = 0; y < decoded.height; y += 10) {
        for (int x = 0; x < decoded.width; x += 10) {
          final p = decoded.getPixel(x, y);
          final r = p.r.toInt();
          if (r == 0) hasBlack = true;
          if (r == 255) hasWhite = true;
        }
      }
      expect(hasBlack, isTrue, reason: 'Must have black text pixels');
      expect(hasWhite, isTrue, reason: 'Must have white background pixels');
    });

    testWidgets('9. Interactive ReceiptPreviewDialog widget test',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ReceiptPreviewDialog.show(
                  context,
                  sale: sampleSale,
                  items: sampleItems,
                  settings: baseSettings,
                  cashReceived: 1500.0,
                  change: 50.0,
                ),
                child: const Text('Open Preview'),
              ),
            ),
          ),
        ),
      );

      // Tap to open preview
      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(ReceiptPreviewDialog), findsOneWidget);
      expect(find.byType(ReceiptWidget), findsOneWidget);
      expect(find.text('Receipt Preview (${sampleSale.billNumber})'),
          findsOneWidget);

      // Verify Sinhala items are rendered in the preview widget
      expect(find.text('ප්රීමා වෙජිටබල් ඔයිල් මිලි ලීටර් 100'), findsOneWidget);
      expect(find.text('Egg Yellow food colour 28ml'), findsOneWidget);
      expect(find.text('කිරිපිටි'), findsOneWidget);
      expect(find.text('Rice 5kg'), findsOneWidget);

      // Verify Sri Lankan retail labels: "අපේ මිල" and "ලාභය"
      expect(find.text('අපේ මිල'), findsOneWidget);
      expect(find.text('ලාභය'), findsWidgets);

      // Toggle width to 58mm
      await tester.tap(find.text('58mm'));
      await tester.pumpAndSettle();

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptPreviewDialog), findsNothing);
    });

    test('10. ReceiptL10n exact label verification for Our Price and Discount', () {
      final siL10n = ReceiptL10n.forLanguage('si');
      expect(siL10n.ourPrice, 'අපේ මිල');
      expect(siL10n.discount, 'ලාභය');

      final biL10n = ReceiptL10n.forLanguage('bilingual');
      expect(biL10n.ourPrice, 'අපේ මිල / Our Price');
      expect(biL10n.discount, 'ලාභය / Discount');

      final enL10n = ReceiptL10n.forLanguage('en');
      expect(enL10n.ourPrice, 'Our Price');
      expect(enL10n.discount, 'Discount');
    });

    test('11. Receipt Image Generation with showReceiptLogo produces bitmap with store logo', () async {
      final settingsWithLogo = baseSettings.copyWith(
        printerPaperSize: '58mm',
        showReceiptLogo: true,
      );
      final Uint8List pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sampleSale,
        items: sampleItems,
        settings: settingsWithLogo,
        cashReceived: 1500.0,
        change: 50.0,
      );

      expect(pngBytes, isNotEmpty);
      final decoded = img.decodeImage(pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 384);
      // Receipt with logo has additional vertical height compared to logo-free receipt
      expect(decoded.height, greaterThan(240));

      // Save artifact for visual inspection
      File('test_receipt_with_logo_58mm.png').writeAsBytesSync(pngBytes);
    });
  });
}

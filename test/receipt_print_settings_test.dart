import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/services/pdf_service.dart';
import 'package:quickbill/utils/receipt_theme.dart';
import 'package:quickbill/widgets/receipt/receipt_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Receipt Print Settings & Paper Dimensions Tests', () {
    test('Standard 80mm paper configuration defaults', () {
      final settings = AppSettings(
        shopName: 'QuickBill Super Store',
        shopAddress: '123 Galle Road, Colombo',
        shopPhone: '011 234 5678',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you for shopping with us!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
      );

      // Default paper widths
      expect(settings.printerPaperSize, '80mm');
      expect(settings.printerPaperWidthMm, 80.0);
      expect(settings.isCustomPaperWidth, isFalse);
      expect(settings.effectivePaperWidthMm, 80.0);
      expect(settings.effectiveReceiptWidthPx, 576.0); // 80mm standard printable px
      expect(settings.is58mm, isFalse);

      // Default margins
      expect(settings.receiptMarginLeftMm, 3.0);
      expect(settings.receiptMarginRightMm, 3.0);
      expect(settings.receiptMarginTopMm, 4.0);
      expect(settings.receiptMarginBottomMm, 6.0);

      // Margins in pixels (mm * 7.2)
      expect(settings.marginLeftPx, closeTo(3.0 * 7.2, 0.01));
      expect(settings.marginRightPx, closeTo(3.0 * 7.2, 0.01));
      expect(settings.marginTopPx, closeTo(4.0 * 7.2, 0.01));
      expect(settings.marginBottomPx, closeTo(6.0 * 7.2, 0.01));

      // Default font sizes
      expect(settings.receiptStoreNameFontSize, 18.0);
      expect(settings.receiptMainFontSize, 12.0);
      expect(settings.receiptProductNameFontSize, 12.0);
      expect(settings.receiptGrandTotalFontSize, 17.0);
      expect(settings.receiptBoldText, isFalse);
      expect(settings.receiptWrapProductName, isTrue);
    });

    test('Compact 58mm paper configuration', () {
      final settings = AppSettings(
        shopName: 'Mobile Shop',
        shopAddress: 'Kandy',
        shopPhone: '081 222 3344',
        lowStockThreshold: 5,
        receiptFooter: 'Visit Again',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '58mm',
        printerPaperWidthMm: 58.0,
        isCustomPaperWidth: false,
      );

      expect(settings.printerPaperSize, '58mm');
      expect(settings.effectivePaperWidthMm, 58.0);
      expect(settings.effectiveReceiptWidthPx, 384.0); // 58mm standard printable px
      expect(settings.is58mm, isTrue);
    });

    test('Custom paper width calculation (e.g. 76mm Kitchen / Impact Roll)', () {
      final settings = AppSettings(
        shopName: 'Kitchen Display',
        shopAddress: 'Colombo',
        shopPhone: '077 123 4567',
        lowStockThreshold: 5,
        receiptFooter: 'Kitchen Order',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Restaurant',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperWidthMm: 76.0,
        isCustomPaperWidth: true,
      );

      expect(settings.isCustomPaperWidth, isTrue);
      expect(settings.effectivePaperWidthMm, 76.0);
      expect(settings.effectiveReceiptWidthPx, closeTo(76.0 * 7.2, 0.1));
    });

    test('ReceiptTheme font sizes adapt dynamically to settings', () {
      final defaultSettings = AppSettings(
        shopName: 'Test Store',
        shopAddress: 'Address',
        shopPhone: '011',
        lowStockThreshold: 5,
        receiptFooter: 'Thanks',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
      );

      final largeFontSettings = defaultSettings.copyWith(
        receiptStoreNameFontSize: 26.0,
        receiptMainFontSize: 15.0,
        receiptProductNameFontSize: 16.0,
        receiptGrandTotalFontSize: 22.0,
        receiptBoldText: true,
      );

      // Store Title styling
      final defaultTitleStyle = ReceiptTheme.storeTitle(false, settings: defaultSettings);
      final largeTitleStyle = ReceiptTheme.storeTitle(false, settings: largeFontSettings);

      expect(defaultTitleStyle.fontSize, 18.0);
      expect(largeTitleStyle.fontSize, 26.0);
      expect(largeTitleStyle.fontWeight, FontWeight.w900); // receiptBoldText = true triggers w900

      // Product Name styling
      final defaultItemStyle = ReceiptTheme.itemName(false, settings: defaultSettings);
      final largeItemStyle = ReceiptTheme.itemName(false, settings: largeFontSettings);

      expect(defaultItemStyle.fontSize, 12.0);
      expect(largeItemStyle.fontSize, 16.0);
      expect(largeItemStyle.fontWeight, FontWeight.w900);

      // Grand Total styling
      final defaultTotalLabelStyle = ReceiptTheme.grandTotalLabel(false, settings: defaultSettings);
      final defaultTotalValueStyle = ReceiptTheme.grandTotalValue(false, settings: defaultSettings);
      final largeTotalValueStyle = ReceiptTheme.grandTotalValue(false, settings: largeFontSettings);

      expect(defaultTotalLabelStyle.fontSize, 17.0);
      expect(defaultTotalValueStyle.fontSize, closeTo(17.0 * 1.1, 0.01));
      expect(largeTotalValueStyle.fontSize, closeTo(22.0 * 1.1, 0.01));
    });

    test('Built-in presets application via copyWith / update', () {
      final baseSettings = AppSettings(
        shopName: 'Test Store',
        shopAddress: 'Address',
        shopPhone: '011',
        lowStockThreshold: 5,
        receiptFooter: 'Thanks',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
      );

      // Apply Large Text preset
      final largePreset = baseSettings.copyWith(
        receiptActivePreset: 'large',
        printerPaperSize: '80mm',
        printerPaperWidthMm: 80.0,
        isCustomPaperWidth: false,
        receiptMarginLeftMm: 2.0,
        receiptMarginRightMm: 2.0,
        receiptMarginTopMm: 4.0,
        receiptMarginBottomMm: 6.0,
        receiptMainFontSize: 13.5,
        receiptStoreNameFontSize: 24.0,
        receiptProductNameFontSize: 14.0,
        receiptQtyPriceFontSize: 13.0,
        receiptSubtotalFontSize: 13.0,
        receiptDiscountFontSize: 13.0,
        receiptGrandTotalFontSize: 20.0,
        receiptFooterFontSize: 12.0,
        receiptLineSpacing: 1.25,
        receiptBoldText: true,
      );

      expect(largePreset.receiptActivePreset, 'large');
      expect(largePreset.receiptStoreNameFontSize, 24.0);
      expect(largePreset.receiptGrandTotalFontSize, 20.0);
      expect(largePreset.receiptBoldText, isTrue);

      // Apply Compact 58mm preset
      final compactPreset = baseSettings.copyWith(
        receiptActivePreset: 'compact',
        printerPaperSize: '58mm',
        printerPaperWidthMm: 58.0,
        isCustomPaperWidth: false,
        receiptMarginLeftMm: 2.0,
        receiptMarginRightMm: 2.0,
        receiptMarginTopMm: 3.0,
        receiptMarginBottomMm: 4.0,
        receiptMainFontSize: 11.0,
        receiptStoreNameFontSize: 16.0,
        receiptProductNameFontSize: 11.0,
        receiptQtyPriceFontSize: 10.5,
        receiptSubtotalFontSize: 10.5,
        receiptDiscountFontSize: 10.5,
        receiptGrandTotalFontSize: 14.0,
        receiptFooterFontSize: 9.5,
        receiptLineSpacing: 1.1,
        receiptItemSpacing: 3.0,
        receiptHeaderSpacing: 6.0,
        receiptFooterSpacing: 6.0,
      );

      expect(compactPreset.receiptActivePreset, 'compact');
      expect(compactPreset.effectivePaperWidthMm, 58.0);
      expect(compactPreset.is58mm, isTrue);
      expect(compactPreset.receiptStoreNameFontSize, 16.0);
    });

    test('AppSettings Serialization: toMap preserves all receipt print settings', () {
      final original = AppSettings(
        shopName: 'QuickBill Serialization Test',
        shopAddress: 'Kandy Road',
        shopPhone: '071 999 8888',
        lowStockThreshold: 5,
        receiptFooter: 'Best Regards',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Grocery',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: 'custom',
        printerPaperWidthMm: 72.0,
        isCustomPaperWidth: true,
        receiptMarginLeftMm: 4.5,
        receiptMarginRightMm: 4.5,
        receiptMarginTopMm: 5.0,
        receiptMarginBottomMm: 7.0,
        receiptMainFontSize: 13.0,
        receiptStoreNameFontSize: 22.0,
        receiptProductNameFontSize: 13.5,
        receiptQtyPriceFontSize: 12.0,
        receiptSubtotalFontSize: 12.0,
        receiptDiscountFontSize: 12.0,
        receiptGrandTotalFontSize: 18.0,
        receiptFooterFontSize: 11.0,
        receiptLineSpacing: 1.3,
        receiptBoldText: true,
        receiptHeaderAlignment: 'center',
        receiptFooterAlignment: 'left',
        receiptWrapProductName: false,
        receiptItemSpacing: 5.0,
        receiptHeaderSpacing: 10.0,
        receiptFooterSpacing: 8.0,
        showReceiptAddress: false,
        showReceiptPhone: true,
        showReceiptDateTime: false,
        receiptActivePreset: 'custom_kitchen',
      );

      final map = original.toMap();

      expect(map['printer_paper_width_mm'], 72.0);
      expect(map['is_custom_paper_width'], true);
      expect(map['receipt_margin_left_mm'], 4.5);
      expect(map['receipt_margin_right_mm'], 4.5);
      expect(map['receipt_margin_top_mm'], 5.0);
      expect(map['receipt_margin_bottom_mm'], 7.0);
      expect(map['receipt_store_name_font_size'], 22.0);
      expect(map['receipt_bold_text'], true);
      expect(map['receipt_wrap_product_name'], false);
      expect(map['show_receipt_address'], false);
      expect(map['show_receipt_date_time'], false);
      expect(map['receipt_active_preset'], 'custom_kitchen');
    });

    test('PdfService.buildImageReceiptDocument respects custom roll width and zero margin', () async {
      // 1x1 dummy PNG bytes
      final dummyPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      // 80mm PDF
      final pdf80 = await PdfService.instance.buildImageReceiptDocument(
        dummyPng,
        is58mm: false,
        customWidthMm: 80.0,
      );

      final doc80Bytes = await pdf80.save();
      expect(doc80Bytes.isNotEmpty, isTrue);

      // 58mm PDF
      final pdf58 = await PdfService.instance.buildImageReceiptDocument(
        dummyPng,
        is58mm: true,
        customWidthMm: 58.0,
      );

      final doc58Bytes = await pdf58.save();
      expect(doc58Bytes.isNotEmpty, isTrue);

      // Verify custom width calculation
      final expectedWidth80Pt = 80.0 * PdfPageFormat.mm;
      final expectedWidth58Pt = 58.0 * PdfPageFormat.mm;
      expect(expectedWidth80Pt, closeTo(226.77, 0.1));
      expect(expectedWidth58Pt, closeTo(164.40, 0.1));
    });
  });

  group('ReceiptWidget Rendering Tests with Custom Print Settings', () {
    late Sale sampleSale;
    late List<SaleItem> sampleItems;

    setUp(() {
      sampleItems = [
        SaleItem(
          id: 1,
          saleId: 901,
          productId: 10,
          productName: 'Highland Fresh Milk 1L / නැවුම් කිරි',
          quantity: 2.0,
          unitPrice: 520.0,
          total: 980.0,
          discount: 60.0,
          costPrice: 420.0,
          soldUnit: 'bottle',
          sellingMode: 'pack',
        ),
        SaleItem(
          id: 2,
          saleId: 901,
          productId: 11,
          productName: 'Keells Keeri Samba Rice 5kg / සම්බා සහල්',
          quantity: 1.0,
          unitPrice: 1450.0,
          total: 1450.0,
          discount: 0.0,
          costPrice: 1200.0,
          soldUnit: 'kg',
          sellingMode: 'weight',
        ),
      ];

      sampleSale = Sale(
        id: 901,
        billNumber: 'INV-TEST-001',
        total: 2430.0,
        discount: 60.0,
        tax: 0.0,
        serviceCharge: 0.0,
        itemsCount: sampleItems.length,
        paymentMethod: 'cash',
        cashierName: 'Sunil Shantha',
        customerName: 'A. Perera',
        customerPhone: '077 111 2233',
        notes: 'Cash received 3000.00, Change 570.00',
        createdAt: DateTime(2026, 9, 14, 15, 30),
        items: sampleItems,
      );
    });

    testWidgets('ReceiptWidget renders seamlessly on 80mm with custom margins & fonts', (tester) async {
      final settings = AppSettings(
        shopName: 'Super Grocers PVT LTD',
        shopAddress: 'No 45, Temple Road, Colombo 03',
        shopPhone: '011 234 5678',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you! Come again.',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '80mm',
        printerPaperWidthMm: 80.0,
        receiptMarginLeftMm: 4.0,
        receiptMarginRightMm: 4.0,
        receiptMarginTopMm: 5.0,
        receiptMarginBottomMm: 8.0,
        receiptStoreNameFontSize: 22.0,
        receiptMainFontSize: 13.0,
        receiptBoldText: true,
        receiptWrapProductName: true,
        showReceiptAddress: true,
        showReceiptPhone: true,
        showReceiptDateTime: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptWidget(
                sale: sampleSale,
                items: sampleItems,
                settings: settings,
                cashReceived: 3000.0,
                change: 570.0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text elements exist and render
      expect(find.text('SUPER GROCERS PVT LTD'), findsOneWidget);
      expect(find.text('No 45, Temple Road, Colombo 03'), findsOneWidget);
      expect(find.textContaining('011 234 5678'), findsOneWidget);
      expect(find.text('Highland Fresh Milk 1L / නැවුම් කිරි'), findsOneWidget);
      expect(find.text('Keells Keeri Samba Rice 5kg / සම්බා සහල්'), findsOneWidget);
      expect(find.text('Thank you! Come again.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReceiptWidget renders cleanly on 58mm compact width without layout overflows', (tester) async {
      final settings = AppSettings(
        shopName: 'Small Kiosk',
        shopAddress: 'Kandy Station',
        shopPhone: '081 555 6677',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '58mm',
        printerPaperWidthMm: 58.0,
        isCustomPaperWidth: false,
        receiptMarginLeftMm: 2.0,
        receiptMarginRightMm: 2.0,
        receiptMarginTopMm: 3.0,
        receiptMarginBottomMm: 4.0,
        receiptStoreNameFontSize: 16.0,
        receiptMainFontSize: 11.0,
        receiptWrapProductName: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptWidget(
                sale: sampleSale,
                items: sampleItems,
                settings: settings,
                cashReceived: 3000.0,
                change: 570.0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SMALL KIOSK'), findsOneWidget);
      expect(find.textContaining('INV-TEST-001'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}

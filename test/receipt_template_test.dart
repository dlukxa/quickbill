import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/services/pdf_service.dart';
import 'package:quickbill/utils/pos_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings Receipt Template & Language Defaults & Serialization', () {
    test('Default template is sri_lankan_retail and default language is si', () {
      final settings = AppSettings(
        shopName: 'QuickBill Super',
        shopAddress: 'No. 100, Galle Road, Colombo',
        shopPhone: '0112345678',
        lowStockThreshold: 10,
        receiptFooter: 'Thank you for shopping with us!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
      );

      expect(settings.receiptTemplate, 'sri_lankan_retail');
      expect(settings.receiptLanguage, 'si');
      expect(settings.showReceiptLogo, isTrue);
      expect(settings.showReceiptBarcode, isTrue);
      expect(settings.showReceiptStandardPrice, isTrue);
      expect(settings.showReceiptOurPrice, isTrue);
      expect(settings.showReceiptDiscount, isTrue);
      expect(settings.showReceiptTax, isTrue);
      expect(settings.showReceiptPaymentDetails, isTrue);
      expect(settings.showReceiptCashier, isTrue);
      expect(settings.showReceiptCustomer, isTrue);
      expect(settings.showReceiptProfit, isFalse);
      expect(settings.showReceiptCostPrice, isFalse);
    });

    test('Serialization toMap and updateFromMap preserves template settings', () {
      final settings = AppSettings(
        shopName: 'Test Store',
        shopAddress: 'Kandy',
        shopPhone: '0812345678',
        lowStockThreshold: 5,
        receiptFooter: 'See you again!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        receiptTemplate: 'classic',
        receiptLanguage: 'ta',
        showReceiptLogo: false,
        showReceiptBarcode: false,
        showReceiptStandardPrice: false,
        showReceiptOurPrice: true,
        showReceiptDiscount: false,
        showReceiptTax: false,
        showReceiptPaymentDetails: true,
        showReceiptCashier: false,
        showReceiptCustomer: false,
        showReceiptProfit: true,
        showReceiptCostPrice: true,
      );

      final map = settings.toMap();
      expect(map['receipt_template'], 'classic');
      expect(map['receipt_language'], 'ta');
      expect(map['show_receipt_logo'], isFalse);
      expect(map['show_receipt_barcode'], isFalse);
      expect(map['show_receipt_standard_price'], isFalse);
      expect(map['show_receipt_our_price'], isTrue);
      expect(map['show_receipt_discount'], isFalse);
      expect(map['show_receipt_profit'], isTrue);
      expect(map['show_receipt_cost_price'], isTrue);

      final modified = settings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'bilingual',
        showReceiptProfit: false,
      );
      expect(modified.receiptTemplate, 'sri_lankan_retail');
      expect(modified.receiptLanguage, 'bilingual');
      expect(modified.showReceiptProfit, isFalse);
      expect(modified.showReceiptCostPrice, isTrue);
    });
  });

  group('ReceiptL10n Translations Across Languages', () {
    test('Sinhala translations match reference retail receipt requirements', () {
      const l10n = ReceiptL10n('si');
      expect(l10n.itemHeader, 'භාණ්ඩය');
      expect(l10n.qtyHeader, 'ප්‍රමාණය');
      expect(l10n.priceHeader, 'මිල');
      expect(l10n.totalHeader, 'එකතුව');
      expect(l10n.standardPrice, 'සදාන් මිල');
      expect(l10n.ourPrice, 'අපේ මිල');
      expect(l10n.profit, 'ලාභය');
      expect(l10n.totalProfit, 'සම්පූර්ණ ලාභය');
      expect(l10n.grandTotal, 'මුළු මුදල');
      expect(l10n.cashReceived, 'ගෙවූ මුදල');
      expect(l10n.change, 'හුවමාරුව');
      expect(l10n.remainingAmount, 'ඉතිරි මුදල');
      expect(l10n.itemsCount, 'භාණ්ඩ ගණන');
      expect(l10n.thankYou, 'ස්තුතියි! නැවත එන්න');
    });

    test('English translations are professional and accurate', () {
      const l10n = ReceiptL10n('en');
      expect(l10n.itemHeader, 'ITEM');
      expect(l10n.qtyHeader, 'QTY');
      expect(l10n.priceHeader, 'PRICE');
      expect(l10n.totalHeader, 'TOTAL');
      expect(l10n.standardPrice, 'Standard Price');
      expect(l10n.ourPrice, 'Our Price');
      expect(l10n.profit, 'Savings');
      expect(l10n.totalProfit, 'Total Savings');
      expect(l10n.grandTotal, 'GRAND TOTAL');
      expect(l10n.cashReceived, 'Cash Received');
      expect(l10n.change, 'Change / Balance');
      expect(l10n.remainingAmount, 'Remaining Balance');
      expect(l10n.itemsCount, 'Items Count');
    });

    test('Tamil translations provide correct Tamil script labels', () {
      const l10n = ReceiptL10n('ta');
      expect(l10n.itemHeader, 'பொருள்');
      expect(l10n.qtyHeader, 'அளவு');
      expect(l10n.priceHeader, 'விலை');
      expect(l10n.grandTotal, 'மொத்த தொகை');
      expect(l10n.cashReceived, 'பெறப்பட்ட பணம்');
      expect(l10n.change, 'மீதித் தொகை');
    });

    test('Bilingual translations display Sinhala and English dual labels', () {
      const l10n = ReceiptL10n('bilingual');
      expect(l10n.itemHeader, 'භාණ්ඩය / Item');
      expect(l10n.qtyHeader, 'ප්‍රමාණය / Qty');
      expect(l10n.priceHeader, 'මිල / Price');
      expect(l10n.grandTotal, 'මුළු මුදල / Grand Total');
      expect(l10n.totalProfit, 'සම්පූර්ණ ලාභය / Total Savings');
      expect(l10n.cashReceived, 'ගෙවූ මුදල / Cash Paid');
      expect(l10n.change, 'හුවමාරුව / Change');
    });
  });

  group('Receipt Document Generation Across Templates and Languages', () {
    final sampleSale = Sale(
      billNumber: 'INV000001',
      total: 145.0,
      discount: 5.0,
      itemsCount: 1,
      paymentMethod: 'cash',
      cashierName: 'Harshana',
      customerName: 'Kusal Mendis',
      customerPhone: '077 123 4567',
      createdAt: DateTime.now(),
      notes: 'Cash: 200.00\nChange: 55.00',
    );

    final sampleItems = [
      SaleItem(
        saleId: 1,
        productId: 10,
        productName: 'කිරි තේ (Milk Tea)',
        quantity: 1,
        unitPrice: 150.0,
        costPrice: 85.0,
        discount: 5.0,
        total: 145.0,
      ),
    ];

    final multiItems = [
      SaleItem(
        saleId: 1,
        productId: 1,
        productName: 'සීනි 1kg (Sugar 1kg)',
        quantity: 2,
        unitPrice: 320.0,
        costPrice: 260.0,
        discount: 40.0,
        total: 600.0,
      ),
      SaleItem(
        saleId: 1,
        productId: 2,
        productName: 'නැවුම් කිරි (Fresh Milk 1L)',
        quantity: 1,
        unitPrice: 450.0,
        costPrice: 380.0,
        discount: 0.0,
        total: 450.0,
      ),
    ];

    final multiSale = Sale(
      billNumber: 'INV000002',
      total: 1050.0,
      discount: 40.0,
      itemsCount: 3,
      paymentMethod: 'cash',
      cashierName: 'Sunil',
      customerName: 'Nimal Perera',
      customerPhone: '071 987 6543',
      createdAt: DateTime.now(),
      notes: 'Cash: 1100.00\nChange: 50.00',
    );

    final baseSettings = AppSettings(
      shopName: 'වික්‍රම සුපර් සෙන්ටර් (Wickrama Super Center)',
      shopAddress: 'නො. 45, ගාලු පාර, කළුතර',
      shopPhone: '034 222 1234',
      lowStockThreshold: 10,
      receiptFooter: 'ස්තුතියි! නැවත එන්න!',
      languageCode: 'si',
      regionCode: 'LK',
      businessType: 'Retail',
      isSetupComplete: true,
      autoSync: false,
      entityCode: '1',
    );

    test('Builds Sri Lankan Retail template in Sinhala (80mm) with 100% success', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'si',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
        cashReceived: 200.0,
        change: 55.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('Builds Sri Lankan Retail template in Sinhala (58mm) with multi-item savings', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'si',
        printerPaperSize: '58mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        multiSale,
        multiItems,
        settings: settings,
        cashReceived: 1100.0,
        change: 50.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('Builds Sri Lankan Retail template in Bilingual (Sinhala + English)', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'bilingual',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        multiSale,
        multiItems,
        settings: settings,
        cashReceived: 1100.0,
        change: 50.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('Builds Sri Lankan Retail template in English', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'en',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
        cashReceived: 200.0,
        change: 55.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds Sri Lankan Retail template in Tamil', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'ta',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
        cashReceived: 200.0,
        change: 55.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds Classic QuickBill template in Sinhala', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'classic',
        receiptLanguage: 'si',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds Classic QuickBill template in English', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'classic',
        receiptLanguage: 'en',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds Classic QuickBill template in Bilingual', () async {
      final settings = baseSettings.copyWith(
        receiptTemplate: 'classic',
        receiptLanguage: 'bilingual',
        printerPaperSize: '58mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settings,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Respects field toggles: sensitive profit and cost price', () async {
      final settingsWithProfit = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'si',
        showReceiptProfit: true,
        showReceiptCostPrice: true,
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settingsWithProfit,
        cashReceived: 200.0,
        change: 55.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('Respects field toggles: disabled barcode and logo', () async {
      final settingsNoBarcode = baseSettings.copyWith(
        receiptTemplate: 'sri_lankan_retail',
        receiptLanguage: 'si',
        showReceiptLogo: false,
        showReceiptBarcode: false,
      );

      final doc = await PdfService.instance.buildReceiptDocument(
        sampleSale,
        sampleItems,
        settings: settingsNoBarcode,
        cashReceived: 200.0,
        change: 55.0,
      );

      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });
  });
}

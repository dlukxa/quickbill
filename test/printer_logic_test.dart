import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/services/pdf_service.dart';
import 'package:quickbill/services/printing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Printer Settings & AppSettings Tests', () {
    test('Default printer settings', () {
      final settings = AppSettings(
        shopName: 'Test Shop',
        shopAddress: 'Colombo',
        shopPhone: '0771234567',
        lowStockThreshold: 10,
        receiptFooter: 'Thank you',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
      );

      expect(settings.printerConnectionType, 'bluetooth');
      expect(settings.printerPaperSize, '80mm');
      expect(settings.is58mm, isFalse);
      expect(settings.printerIpAddress, '192.168.1.100');
      expect(settings.printerPort, 9100);
      expect(settings.autoPrintReceipt, isFalse);
    });

    test('58mm paper size configuration', () {
      final settings = AppSettings(
        shopName: 'Test Shop',
        shopAddress: 'Colombo',
        shopPhone: '0771234567',
        lowStockThreshold: 10,
        receiptFooter: 'Thank you',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '58mm',
        printerConnectionType: 'network',
        printerIpAddress: '192.168.8.50',
        printerPort: 9100,
        autoPrintReceipt: true,
      );

      expect(settings.is58mm, isTrue);
      expect(settings.printerConnectionType, 'network');
      expect(settings.printerIpAddress, '192.168.8.50');
      expect(settings.autoPrintReceipt, isTrue);

      final map = settings.toMap();
      expect(map['printer_paper_size'], '58mm');
      expect(map['printer_connection_type'], 'network');
      expect(map['printer_ip_address'], '192.168.8.50');
      expect(map['auto_print_receipt'], isTrue);
    });
  });

  group('PrintingService Contains Sinhala Detection Tests', () {
    final defaultSettings = AppSettings(
      shopName: 'QuickBill Super',
      shopAddress: 'No. 12, Main Street',
      shopPhone: '0112345678',
      lowStockThreshold: 10,
      receiptFooter: 'Thank you for shopping!',
      languageCode: 'en',
      regionCode: 'LK',
      businessType: 'Retail',
      isSetupComplete: true,
      autoSync: false,
      entityCode: '1',
    );

    final sinhalaShopSettings = defaultSettings.copyWith(
      shopName: 'සිරිලක වෙළඳසැල',
    );

    final asciiSale = Sale(
      billNumber: 'INV-1001',
      total: 500,
      itemsCount: 1,
      paymentMethod: 'CASH',
      cashierName: 'Nimal',
      customerName: 'Kamal',
      createdAt: DateTime.now(),
    );

    final List<SaleItem> asciiItems = [
      SaleItem(saleId: 1, productId: 1, productName: 'Anchor Milk 400g', quantity: 1, unitPrice: 500, costPrice: 400, total: 500),
    ];

    final List<SaleItem> sinhalaItems = [
      SaleItem(saleId: 1, productId: 2, productName: 'කිරි තේ', quantity: 2, unitPrice: 150, costPrice: 80, total: 300),
    ];

    test('Pure ASCII receipt returns false for containsSinhala', () {
      final hasSinhala = PrintingService.instance.containsSinhala(asciiSale, asciiItems, defaultSettings);
      expect(hasSinhala, isFalse);
    });

    test('Sinhala product name triggers containsSinhala true', () {
      final hasSinhala = PrintingService.instance.containsSinhala(asciiSale, sinhalaItems, defaultSettings);
      expect(hasSinhala, isTrue);
    });

    test('Sinhala shop name triggers containsSinhala true', () {
      final hasSinhala = PrintingService.instance.containsSinhala(asciiSale, asciiItems, sinhalaShopSettings);
      expect(hasSinhala, isTrue);
    });
  });

  group('PDF Document Generation Tests for 58mm and 80mm', () {
    final sale = Sale(
      billNumber: 'INV-2026',
      total: 450,
      itemsCount: 3,
      paymentMethod: 'CASH',
      cashierName: 'කැෂියර් 01',
      customerName: 'සුනිල්',
      createdAt: DateTime.now(),
    );

    final List<SaleItem> items = [
      SaleItem(saleId: 1, productId: 1, productName: 'කිරි තේ', quantity: 1, unitPrice: 150, costPrice: 80, total: 150),
      SaleItem(saleId: 1, productId: 2, productName: 'කිරිබත්', quantity: 1, unitPrice: 200, costPrice: 120, total: 200),
      SaleItem(saleId: 1, productId: 3, productName: 'පාන්', quantity: 1, unitPrice: 100, costPrice: 70, total: 100),
    ];

    test('Builds 80mm receipt document with Sinhala text without errors', () async {
      final settings80 = AppSettings(
        shopName: 'සුපිරි වෙළඳසැල',
        shopAddress: 'කොළඹ පාර, නුවර',
        shopPhone: '0812345678',
        lowStockThreshold: 10,
        receiptFooter: 'ස්තුතියි! නැවත එන්න!',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings80);
      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds 58mm receipt document with Sinhala text without errors', () async {
      final settings58 = AppSettings(
        shopName: 'සුපිරි වෙළඳසැල',
        shopAddress: 'කොළඹ පාර, නුවර',
        shopPhone: '0812345678',
        lowStockThreshold: 10,
        receiptFooter: 'ස්තුතියි! නැවත එන්න!',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '58mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings58);
      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('Builds mixed Sinhala + English receipt with various units (kg, g, pcs, pack, ml, L)', () async {
      final mixedSale = Sale(
        billNumber: 'INV-MIX-2026',
        total: 1525.00,
        itemsCount: 5,
        paymentMethod: 'CASH',
        cashierName: 'නිමල් පෙරේරා',
        customerName: 'සුනිල් ශාන්ත',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> mixedItems = [
        SaleItem(
          saleId: 1,
          productId: 1,
          productName: 'සීනි (White Sugar)',
          quantity: 0.5,
          unitPrice: 250,
          costPrice: 200,
          total: 125,
          soldUnit: 'g',
          soldQuantity: 500,
          sellingMode: 'weight',
        ),
        SaleItem(
          saleId: 1,
          productId: 2,
          productName: 'Fresh Milk',
          quantity: 1,
          unitPrice: 450,
          costPrice: 380,
          total: 450,
          soldUnit: 'L',
          soldQuantity: 1,
        ),
        SaleItem(
          saleId: 1,
          productId: 3,
          productName: 'සබන් (Sunlight Soap)',
          quantity: 2,
          unitPrice: 150,
          costPrice: 110,
          total: 300,
          soldUnit: 'pcs',
          soldQuantity: 2,
        ),
        SaleItem(
          saleId: 1,
          productId: 4,
          productName: 'ක්‍රීම් ක්‍රැකර් බිස්කට් පැකට්ටුව',
          quantity: 1,
          unitPrice: 220,
          costPrice: 180,
          total: 220,
          soldUnit: 'pack',
          soldQuantity: 1,
          sellingMode: 'pack',
        ),
        SaleItem(
          saleId: 1,
          productId: 5,
          productName: 'පොල් තෙල් (Coconut Oil)',
          quantity: 0.75,
          unitPrice: 500,
          costPrice: 400,
          total: 375,
          soldUnit: 'ml',
          soldQuantity: 750,
        ),
      ];

      final settings = AppSettings(
        shopName: 'QuickBill Super Center (ක්වික්බිල්)',
        shopAddress: '123, High Level Road, Maharagama',
        shopPhone: '011 284 5678',
        lowStockThreshold: 10,
        receiptFooter: 'ස්තුතියි! නැවත එන්න! / Thank you for shopping!',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '80mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(mixedSale, mixedItems, settings: settings);
      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });

    test('Handles complex Sinhala conjuncts (අ, ආ, ඇ, ක, කි, කී, කු, කූ, ක්, ක්‍ර, ශ්, ත්, න්, ස්තුතියි, මුළු එකතුව)', () async {
      final complexSale = Sale(
        billNumber: 'INV-SINHALA-001',
        total: 825.00,
        itemsCount: 3,
        paymentMethod: 'CARD',
        cashierName: 'ක්‍රිශාන්ත ප්‍රනාන්දු',
        customerName: 'ආනන්ද කුමාර',
        createdAt: DateTime.now(),
      );

      final List<SaleItem> complexItems = [
        SaleItem(
          saleId: 1,
          productId: 1,
          productName: 'කිරි තේ විශේෂ කුඩු (ඇසුරුම)',
          quantity: 1,
          unitPrice: 350,
          costPrice: 280,
          total: 350,
          soldUnit: 'pack',
          soldQuantity: 1,
        ),
        SaleItem(
          saleId: 1,
          productId: 2,
          productName: 'කිරිබත් කෑලි 4 ක් (ආප්ප සමග)',
          quantity: 4,
          unitPrice: 75,
          costPrice: 40,
          total: 300,
          soldUnit: 'pcs',
          soldQuantity: 4,
        ),
        SaleItem(
          saleId: 1,
          productId: 3,
          productName: 'රසවත් කුකුළු මස් කරිය (ග්‍රෑම් 250)',
          quantity: 0.25,
          unitPrice: 700,
          costPrice: 500,
          total: 175,
          soldUnit: 'g',
          soldQuantity: 250,
        ),
      ];

      final settings = AppSettings(
        shopName: 'ආපනශාලාව හා හෝටලය',
        shopAddress: 'අංක 45, ගාලු පාර, කොළඹ',
        shopPhone: '011 234 5678',
        lowStockThreshold: 10,
        receiptFooter: 'ස්තුතියි! නැවත එන්න! මුළු එකතුව පරීක්ෂා කරන්න.',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Restaurant',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: '58mm',
      );

      final doc = await PdfService.instance.buildReceiptDocument(complexSale, complexItems, settings: settings);
      final bytes = await doc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(1500));
    });
  });
}

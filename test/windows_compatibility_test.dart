import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/services/cash_drawer_service.dart';
import 'package:quickbill/services/subscription_service.dart';
import 'package:quickbill/services/printing_service.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/models/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Windows POS Architecture & Runtime Safety Tests', () {
    test('SQLite FFI is registered and usable in production dependencies', () {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      expect(databaseFactory, isNotNull);
    });

    test('SubscriptionService initializes cleanly without crashing on desktop', () {
      final subService = SubscriptionService.instance;
      expect(subService, isNotNull);
    });

    test('Universal ESC/POS Cash Drawer kick bytes conform to POS standards', () {
      // Epson Pin 2 pulse: ESC p 0 25 250 -> [27, 112, 0, 25, 250]
      // Epson Pin 5 pulse: ESC p 1 25 250 -> [27, 112, 1, 25, 250]
      // Star Micronics: BEL -> [7]
      const expected = [27, 112, 0, 25, 250, 27, 112, 1, 25, 250, 7];
      expect(CashDrawerService.universalKickBytes, equals(expected));
    });

    test('CashDrawerService handles Windows configuration gracefully', () async {
      final settings = AppSettings(
        shopName: 'Test Shop',
        shopAddress: '123 Test Street',
        shopPhone: '0771234567',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
        printerConnectionType: 'system',
        selectedPrinterName: 'POS-80',
        cashDrawerTriggerType: 'printer',
      );

      final result = await CashDrawerService.instance.openCashDrawer(settings);
      expect(result, isNotNull);
    });

    test('PrintingService detects Sinhala text requiring raster rendering for thermal printers', () {
      final sale = Sale(
        billNumber: 'INV-1001',
        total: 500.0,
        discount: 0.0,
        itemsCount: 1,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

      final englishSettings = AppSettings(
        shopName: 'QuickBill Supermarket',
        shopAddress: '123 Main Street',
        shopPhone: '0771234567',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you for shopping!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
      );

      expect(PrintingService.instance.containsSinhala(sale, [], englishSettings), isFalse);

      final sinhalaSettings = AppSettings(
        shopName: 'සුපිරි වෙළඳසැල',
        shopAddress: 'නො. 12, ගාලු පාර',
        shopPhone: '0771234567',
        lowStockThreshold: 5,
        receiptFooter: 'ස්තූතියි!',
        languageCode: 'si',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
      );

      expect(PrintingService.instance.containsSinhala(sale, [], sinhalaSettings), isTrue);
    });
  });
}

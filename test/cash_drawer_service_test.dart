import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/services/cash_drawer_service.dart';

void main() {
  group('Cash Drawer Architecture & ESC/POS Protocol Tests', () {
    test('Universal ESC/POS kick pulse payload includes Pin 2, Pin 5, and Star BEL', () {
      final bytes = CashDrawerService.universalKickBytes;

      // Pin 2: ESC p 0 25 250
      expect(bytes.sublist(0, 5), equals([27, 112, 0, 25, 250]));

      // Pin 5: ESC p 1 25 250
      expect(bytes.sublist(5, 10), equals([27, 112, 1, 25, 250]));

      // Star Micronics: BEL (0x07)
      expect(bytes[10], equals(7));
      expect(bytes.length, equals(11));
    });

    test('AppSettings initializes with enabled cash drawer defaults for desktop POS', () {
      final settings = AppSettings(
        shopName: 'Test Store',
        shopAddress: 'Colombo',
        shopPhone: '0771234567',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
      );

      expect(settings.autoOpenCashDrawerOnCashStart, isTrue);
      expect(settings.autoOpenCashDrawerOnSaleComplete, isTrue);
      expect(settings.cashDrawerTriggerType, equals('printer'));
      expect(settings.cashDrawerComPort, equals('COM1'));
    });

    test('AppSettings copyWith and toMap accurately serialize cash drawer properties', () {
      final settings = AppSettings(
        shopName: 'Test Store',
        shopAddress: '',
        shopPhone: '',
        lowStockThreshold: 5,
        receiptFooter: '',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
      );

      final updated = settings.copyWith(
        autoOpenCashDrawerOnCashStart: false,
        autoOpenCashDrawerOnSaleComplete: false,
        cashDrawerTriggerType: 'com_port',
        cashDrawerComPort: 'COM3',
      );

      expect(updated.autoOpenCashDrawerOnCashStart, isFalse);
      expect(updated.autoOpenCashDrawerOnSaleComplete, isFalse);
      expect(updated.cashDrawerTriggerType, equals('com_port'));
      expect(updated.cashDrawerComPort, equals('COM3'));

      final map = updated.toMap();
      expect(map['auto_open_cash_drawer_on_cash_start'], isFalse);
      expect(map['auto_open_cash_drawer_on_sale_complete'], isFalse);
      expect(map['cash_drawer_trigger_type'], equals('com_port'));
      expect(map['cash_drawer_com_port'], equals('COM3'));
    });

    test('CashDrawerService throttles consecutive rapid kick requests safely', () async {
      final settings = AppSettings(
        shopName: 'Test Store',
        shopAddress: '',
        shopPhone: '',
        lowStockThreshold: 5,
        receiptFooter: '',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
        printerConnectionType: 'system',
      );

      // First kick executes
      final res1 = await CashDrawerService.instance.openCashDrawer(settings);
      expect(res1, isA<DrawerKickResult>());

      // Immediate second kick within 600ms is gracefully debounced
      final res2 = await CashDrawerService.instance.openCashDrawer(settings);
      expect(res2.success, isTrue);
      expect(res2.message, contains('already triggered'));
    });

    test('CashDrawerService handles unconfigured network printer gracefully without crashing', () async {
      final settings = AppSettings(
        shopName: 'Test Store',
        shopAddress: '',
        shopPhone: '',
        lowStockThreshold: 5,
        receiptFooter: '',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: true,
        entityCode: '1',
        printerConnectionType: 'network',
        printerIpAddress: '   ', // Empty/blank IP
      );

      // Wait 700ms to clear previous test throttle
      await Future.delayed(const Duration(milliseconds: 700));

      final res = await CashDrawerService.instance.openCashDrawer(settings);
      expect(res.success, isFalse);
      expect(res.message, contains('not configured'));
    });
  });
}

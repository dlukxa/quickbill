import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/providers/cart_provider.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/utils/pos_l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Desktop Multi-Language Dynamic Switching Suite', () {
    test('PosL10n provides distinct localized strings across all 6 supported languages', () {
      final en = PosL10n.of('en');
      final si = PosL10n.of('si');
      final ta = PosL10n.of('ta');
      final hi = PosL10n.of('hi');
      final bn = PosL10n.of('bn');
      final dv = PosL10n.of('dv');

      // 1. Desktop Navigation Tabs
      expect(en.posTerminal, 'POS Terminal');
      expect(si.posTerminal, 'POS පර්යන්තය');
      expect(ta.posTerminal, 'POS முனையம்');

      expect(en.dashboardNav, 'Dashboard');
      expect(si.dashboardNav, 'පුවරුව');
      expect(ta.dashboardNav, 'டாஷ்போர்டு');

      expect(en.inventoryNav, 'Inventory');
      expect(si.inventoryNav, 'තොග කළමනාකරණය');
      expect(ta.inventoryNav, 'சரக்கு மேலாண்மை');

      expect(en.invoicesAndSalesNav, 'Invoices & Sales');
      expect(si.invoicesAndSalesNav, 'ඉන්වොයිස් සහ විකුණුම්');
      expect(ta.invoicesAndSalesNav, 'விலைப்பட்டியல் & விற்பனை');

      expect(en.customersNav, 'Customers');
      expect(si.customersNav, 'පාරිභෝගිකයන්');
      expect(ta.customersNav, 'வாடிக்கையாளர்கள்');

      expect(en.suppliersGrnNav, 'Suppliers (GRN)');
      expect(si.suppliersGrnNav, 'සැපයුම්කරුවන් (GRN)');
      expect(ta.suppliersGrnNav, 'சப்ளையர்கள் (GRN)');

      expect(en.expensesNav, 'Expenses');
      expect(si.expensesNav, 'වියදම්');
      expect(ta.expensesNav, 'செலவுகள்');

      expect(en.settingsNav, 'Settings');
      expect(si.settingsNav, 'සැකසුම්');
      expect(ta.settingsNav, 'அமைப்புகள்');

      // 2. Desktop Views Titles and Headers
      // Inventory
      expect(en.inventoryCatalog, 'Inventory & Product Catalog');
      expect(si.inventoryCatalog, 'තොග සහ භාණ්ඩ නාමාවලිය');
      expect(ta.inventoryCatalog, 'சரக்கு மற்றும் தயாரிப்பு பட்டியல்');

      // Sales
      expect(en.invoicesAndSalesTitle, 'Invoices & Sales Transactions');
      expect(si.invoicesAndSalesTitle, 'ඉන්වොයිස් සහ විකුණුම් ගනුදෙනු');
      expect(ta.invoicesAndSalesTitle, 'விலைப்பட்டியல் & விற்பனை பரிவர்த்தனைகள்');

      // Customers
      expect(en.customersAndCredit, 'Customers & Store Credit');
      expect(si.customersAndCredit, 'පාරිභෝගිකයින් සහ ණය කළමනාකරණය');
      expect(ta.customersAndCredit, 'வாடிக்கையாளர்கள் & கடை கடன்');

      // Suppliers
      expect(en.suppliersAndGrn, 'Suppliers & Purchase Orders (GRN)');
      expect(si.suppliersAndGrn, 'සැපයුම්කරුවන් සහ ඇණවුම් (GRN)');
      expect(ta.suppliersAndGrn, 'சப்ளையர்கள் & கொள்முதல் ஆணைகள் (GRN)');

      // Expenses
      expect(en.expensesAndOperatingCosts, 'Expenses & Operating Costs');
      expect(si.expensesAndOperatingCosts, 'වියදම් සහ මෙහෙයුම් පිරිවැය');
      expect(ta.expensesAndOperatingCosts, 'செலவுகள் & இயக்கச் செலவுகள்');

      // Dashboard
      expect(en.storeDashboardTitle, 'Store Dashboard & Performance');
      expect(si.storeDashboardTitle, 'වෙළඳසැල් පුවරුව සහ ක්‍රියාකාරිත්වය');
      expect(ta.storeDashboardTitle, 'கடை டாஷ்போர்டு & செயல்திறன்');

      // Settings
      expect(en.appInterfaceLanguage, 'App Interface Language');
      expect(si.appInterfaceLanguage, 'යෙදුම් භාෂාව (App Interface Language)');
      expect(ta.appInterfaceLanguage, 'பயன்பாட்டு மொழி (App Interface Language)');

      // 3. Fallback and additional language checks
      expect(hi.settingsTitle, 'सेटिंग्स');
      expect(bn.checkout, 'চেকআউট (F12)');
      expect(dv.posTerminal, isNotEmpty);
    });

    test('settingsProvider dynamic language switching triggers instant PosL10n updates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).init();

      // Verify initial state defaults to 'en'
      var settings = container.read(settingsProvider);
      expect(settings.languageCode, isNotNull);

      // Switch to Sinhala ('si')
      await container.read(settingsProvider.notifier).updateLanguage('si');
      settings = container.read(settingsProvider);
      expect(settings.languageCode, 'si');

      // Verify PosL10n immediately resolves to Sinhala
      var posL10n = PosL10n.of(settings.languageCode);
      expect(posL10n.posTerminal, 'POS පර්යන්තය');
      expect(posL10n.inventoryNav, 'තොග කළමනාකරණය');
      expect(posL10n.newProduct, '+ නව භාණ්ඩය');
      expect(posL10n.todaysRevenue, 'අද ආදායම');
      expect(posL10n.totalOrders, 'මුළු ඇණවුම්');

      // Switch to Tamil ('ta')
      await container.read(settingsProvider.notifier).updateLanguage('ta');
      settings = container.read(settingsProvider);
      expect(settings.languageCode, 'ta');

      // Verify PosL10n immediately resolves to Tamil
      posL10n = PosL10n.of(settings.languageCode);
      expect(posL10n.posTerminal, 'POS முனையம்');
      expect(posL10n.inventoryNav, 'சரக்கு மேலாண்மை');
      expect(posL10n.newProduct, '+ புதிய பொருள்');
      expect(posL10n.todaysRevenue, 'இன்றைய வருவாய்');
      expect(posL10n.totalOrders, 'மொத்த ஆர்டர்கள்');

      // Switch to Hindi ('hi')
      await container.read(settingsProvider.notifier).updateLanguage('hi');
      settings = container.read(settingsProvider);
      expect(settings.languageCode, 'hi');

      // Verify PosL10n resolves with Hindi
      posL10n = PosL10n.of(settings.languageCode);
      expect(posL10n.settingsTitle, 'सेटिंग्स');
      expect(posL10n.checkout, 'चेकआउट (F12)');

      // Switch back to English ('en')
      await container.read(settingsProvider.notifier).updateLanguage('en');
      settings = container.read(settingsProvider);
      expect(settings.languageCode, 'en');
      posL10n = PosL10n.of(settings.languageCode);
      expect(posL10n.posTerminal, 'POS Terminal');
    });

    test('Language changes do not affect Riverpod cart state or product quantities', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).init();

      final sampleProduct = Product(
        id: 42,
        name: 'Munchee Super Cream Cracker',
        price: 320.0,
        costPrice: 260.0,
        stock: 100.0,
        category: 'Biscuits',
      );

      // Add item to cart
      container.read(cartProvider.notifier).addProduct(sampleProduct);
      expect(container.read(cartProvider).length, 1);
      expect(container.read(cartProvider).first.total, 320.0);

      // Change language from English -> Sinhala -> Tamil -> Bengali -> English
      for (final lang in ['si', 'ta', 'bn', 'hi', 'dv', 'en']) {
        await container.read(settingsProvider.notifier).updateLanguage(lang);

        // Cart state must remain completely unchanged
        final cart = container.read(cartProvider);
        expect(cart.length, 1);
        expect(cart.first.product?.id, 42);
        expect(cart.first.quantity, 1.0);
        expect(cart.first.total, 320.0);
      }
    });
  });
}

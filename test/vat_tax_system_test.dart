import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/utils/tax_calculator.dart';
import 'package:quickbill/widgets/receipt/receipt_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaxCalculator Engine Tests', () {
    test('Inclusive Pricing - 18% Standard VAT on Rs. 118 item', () {
      final items = [
        TaxInputItem(
          productId: 1,
          name: 'Shampoo 200ml',
          quantity: 1,
          unitPrice: 118.0,
          itemDiscount: 0,
          taxStatus: 'taxable',
        ),
      ];

      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: true,
        pricingType: 'inclusive',
        billDiscount: 0,
      );

      // Total charged to customer: 118.00
      expect(result.grandTotal, 118.00);
      // Net Taxable Base: 118 / 1.18 = 100.00
      expect(result.taxableAmount, 100.00);
      // VAT Amount: 118 - 100 = 18.00
      expect(result.totalVat, 18.00);
      expect(result.exemptAmount, 0.0);
      expect(result.zeroRatedAmount, 0.0);

      // Line item breakdown
      expect(result.items.length, 1);
      expect(result.items[0].taxAmount, 18.00);
      expect(result.items[0].taxableAmount, 100.00);
      expect(result.items[0].taxRate, 18.0);
    });

    test('Exclusive Pricing - 18% Standard VAT on Rs. 100 item', () {
      final items = [
        TaxInputItem(
          productId: 1,
          name: 'Office Paper Box',
          quantity: 1,
          unitPrice: 100.0,
          itemDiscount: 0,
          taxStatus: 'taxable',
        ),
      ];

      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: true,
        pricingType: 'exclusive',
        billDiscount: 0,
      );

      // Taxable Base: 100.00
      expect(result.taxableAmount, 100.00);
      // VAT: 100 * 0.18 = 18.00
      expect(result.totalVat, 18.00);
      // Grand Total: 100 + 18 = 118.00
      expect(result.grandTotal, 118.00);
    });

    test('Mixed Cart: Taxable, Zero-Rated, and Exempt Items (Inclusive)', () {
      final items = [
        TaxInputItem(
          productId: 1,
          name: 'Standard Taxable Soap',
          quantity: 1,
          unitPrice: 118.0, // 100 base + 18 VAT
          taxStatus: 'taxable',
        ),
        TaxInputItem(
          productId: 2,
          name: 'Zero-Rated Export Tea',
          quantity: 1,
          unitPrice: 200.0, // 0% VAT
          taxStatus: 'zero_rated',
        ),
        TaxInputItem(
          productId: 3,
          name: 'Exempt Fresh Rice / Bread',
          quantity: 1,
          unitPrice: 150.0, // Exempt
          taxStatus: 'exempt',
        ),
        TaxInputItem(
          productId: 4,
          name: 'Custom 8% Luxury Juice',
          quantity: 1,
          unitPrice: 108.0, // 100 base + 8 VAT
          taxStatus: 'taxable',
          customTaxRate: 8.0,
        ),
      ];

      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: true,
        pricingType: 'inclusive',
        billDiscount: 0,
      );

      // Subtotal before tax breakdown
      expect(result.subtotal, 576.00);
      expect(result.grandTotal, 576.00);

      // Taxable bases: Soap (100) + Luxury Juice (100) = 200
      expect(result.taxableAmount, 200.00);
      // Total VAT: 18 (Soap) + 8 (Juice) = 26.00
      expect(result.totalVat, 26.00);
      // Zero-Rated: 200.00
      expect(result.zeroRatedAmount, 200.00);
      // Exempt: 150.00
      expect(result.exemptAmount, 150.00);

      // Check VAT by rate grouping
      expect(result.vatByRate[18.0], 18.00);
      expect(result.vatByRate[8.0], 8.00);
    });

    test('VAT Disabled - Should produce 0 VAT and treat all as standard non-taxed', () {
      final items = [
        TaxInputItem(
          productId: 1,
          name: 'Sample Item',
          quantity: 2,
          unitPrice: 150.0,
          taxStatus: 'taxable',
        ),
      ];

      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: false,
        pricingType: 'inclusive',
        billDiscount: 0,
      );

      expect(result.totalVat, 0.0);
      expect(result.taxableAmount, 0.0);
      expect(result.grandTotal, 300.00);
    });

    test('Bill Discount Apportionment across Taxable and Exempt Lines', () {
      final items = [
        TaxInputItem(
          productId: 1,
          name: 'Taxable Goods',
          quantity: 1,
          unitPrice: 200.0,
          taxStatus: 'taxable',
        ),
        TaxInputItem(
          productId: 2,
          name: 'Exempt Medicine',
          quantity: 1,
          unitPrice: 200.0,
          taxStatus: 'exempt',
        ),
      ];

      // Total is 400. Bill discount of 40 (10% discount across both lines)
      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: true,
        pricingType: 'exclusive',
        billDiscount: 40.0,
      );

      // Taxable line after 20 discount: 180. VAT: 180 * 0.18 = 32.40
      expect(result.taxableAmount, 180.00);
      expect(result.totalVat, 32.40);
      // Exempt line after 20 discount: 180.00
      expect(result.exemptAmount, 180.00);
      // Grand total: (180 + 180) + 32.40 = 392.40
      expect(result.grandTotal, 392.40);
    });
  });

  group('Model Serialization & Deserialization Tests', () {
    test('Product tax fields support and serialization', () {
      final p = Product(
        id: 101,
        name: 'Anchor Milk Powder 400g',
        price: 1150.0,
        costPrice: 980.0,
        stock: 50,
        taxStatus: 'zero_rated',
        customTaxRate: 0.0,
      );

      final map = p.toMap();
      expect(map['tax_status'], 'zero_rated');
      expect(map['custom_tax_rate'], 0.0);

      final reconstructed = Product.fromMap(map);
      expect(reconstructed.taxStatus, 'zero_rated');
      expect(reconstructed.customTaxRate, 0.0);

      final customP = p.copyWith(taxStatus: 'taxable', customTaxRate: 18.0);
      expect(customP.taxStatus, 'taxable');
      expect(customP.customTaxRate, 18.0);
    });

    test('Product defaults to exempt taxStatus when unspecified or null in DB', () {
      // Default constructor
      final defaultProduct = Product(
        id: 102,
        name: 'Sugar 1kg',
        price: 250.0,
        stock: 20,
      );
      expect(defaultProduct.taxStatus, 'exempt');

      // Legacy DB row with NULL tax_status
      final legacyDbRow = {
        'id': 103,
        'branch_id': 1,
        'name': 'Matchbox',
        'price': 20.0,
        'stock': 100,
        'tax_status': null,
      };
      final fromLegacyDb = Product.fromMap(legacyDbRow);
      expect(fromLegacyDb.taxStatus, isNull);

      // CartItem getter resolves null to 'exempt'
      final cartItem = CartItem(product: fromLegacyDb, quantity: 5);
      expect(cartItem.taxStatus, 'exempt');
    });

    test('TaxCalculator treats null or exempt taxStatus as non-taxable (opt-in VAT)', () {
      final items = [
        TaxInputItem(
          productId: 104,
          name: 'Small Everyday Item',
          quantity: 2,
          unitPrice: 50.0,
          taxStatus: null, // User did not opt-in for VAT
        ),
        TaxInputItem(
          productId: 105,
          name: 'Special Item Marked Taxable',
          quantity: 1,
          unitPrice: 118.0,
          taxStatus: 'taxable', // User explicitly opted-in
        ),
      ];

      final result = TaxCalculator.calculate(
        items: items,
        defaultVatRate: 18.0,
        isVatEnabled: true,
        pricingType: 'inclusive',
        billDiscount: 0,
      );

      // Total = 100 (exempt) + 118 (taxable) = 218
      expect(result.grandTotal, 218.00);
      // Only 118 has VAT: base 100, VAT 18
      expect(result.taxableAmount, 100.00);
      expect(result.totalVat, 18.00);
      // The 100 item was exempt
      expect(result.exemptAmount, 100.00);
    });

    test('Sale snapshot fields persistence and immutability', () {
      final now = DateTime.now();
      final s = Sale(
        id: 55,
        billNumber: 'INV-2026-00055',
        total: 1180.0,
        tax: 180.0,
        taxableAmount: 1000.0,
        taxExemptAmount: 0.0,
        taxZeroRatedAmount: 0.0,
        isVatEnabled: true,
        vatRate: 18.0,
        pricingType: 'inclusive',
        invoiceType: 'tax_invoice',
        customerTin: '123456789-V',
        customerVatNumber: 'VAT-998877',
        itemsCount: 1,
        paymentMethod: 'cash',
        createdAt: now,
      );

      final map = s.toMap();
      expect(map['taxable_amount'], 1000.0);
      expect(map['is_vat_enabled'], 1);
      expect(map['vat_rate'], 18.0);
      expect(map['pricing_type'], 'inclusive');
      expect(map['invoice_type'], 'tax_invoice');
      expect(map['customer_tin'], '123456789-V');
      expect(map['customer_vat_number'], 'VAT-998877');

      final reconstructed = Sale.fromMap(map);
      expect(reconstructed.taxableAmount, 1000.0);
      expect(reconstructed.isVatEnabled, true);
      expect(reconstructed.vatRate, 18.0);
      expect(reconstructed.pricingType, 'inclusive');
      expect(reconstructed.invoiceType, 'tax_invoice');
      expect(reconstructed.customerTin, '123456789-V');
      expect(reconstructed.customerVatNumber, 'VAT-998877');
    });

    test('SaleItem line tax persistence', () {
      final item = SaleItem(
        saleId: 55,
        productId: 101,
        productName: 'Sample Product',
        quantity: 2,
        unitPrice: 590.0,
        total: 1180.0,
        costPrice: 450.0,
        taxStatus: 'taxable',
        taxRate: 18.0,
        taxAmount: 180.0,
        taxableAmount: 1000.0,
      );

      final map = item.toMap();
      expect(map['tax_status'], 'taxable');
      expect(map['tax_rate'], 18.0);
      expect(map['tax_amount'], 180.0);
      expect(map['taxable_amount'], 1000.0);

      final reconstructed = SaleItem.fromMap(map);
      expect(reconstructed.taxStatus, 'taxable');
      expect(reconstructed.taxRate, 18.0);
      expect(reconstructed.taxAmount, 180.0);
      expect(reconstructed.taxableAmount, 1000.0);
    });

    test('SaleItem defaults to exempt and respects CartItem taxStatus', () {
      // Default SaleItem has taxStatus = 'exempt'
      final defaultItem = SaleItem(
        saleId: 1,
        productId: 10,
        productName: 'General Goods',
        quantity: 1,
        unitPrice: 100.0,
        total: 100.0,
        costPrice: 80.0,
      );
      expect(defaultItem.taxStatus, 'exempt');

      // CartItem with exempt product
      final exemptCartItem = CartItem(
        product: Product(id: 1, name: 'Exempt Item', price: 100.0, stock: 10),
        quantity: 1,
      );
      expect(exemptCartItem.taxStatus, 'exempt');

      // CartItem with taxable product
      final taxableCartItem = CartItem(
        product: Product(id: 2, name: 'Taxable Item', price: 100.0, stock: 10, taxStatus: 'taxable'),
        quantity: 1,
      );
      expect(taxableCartItem.taxStatus, 'taxable');
    });
  });

  group('Tax Invoice vs POS Receipt Rendering Tests', () {
    testWidgets('Tax Invoice mode renders TAX INVOICE header, TIN, VAT, and breakdown', (tester) async {
      final sale = Sale(
        id: 1,
        billNumber: 'TAX-INV-001',
        total: 1180.0,
        tax: 180.0,
        taxableAmount: 1000.0,
        taxExemptAmount: 0.0,
        taxZeroRatedAmount: 0.0,
        isVatEnabled: true,
        vatRate: 18.0,
        pricingType: 'inclusive',
        invoiceType: 'tax_invoice',
        customerName: 'Ceylon Corp Ltd',
        customerTin: '998877665-TIN',
        customerVatNumber: '998877665-7000',
        itemsCount: 1,
        paymentMethod: 'cash',
        createdAt: DateTime(2026, 9, 15, 14, 30),
      );

      final items = [
        SaleItem(
          saleId: 1,
          productId: 10,
          productName: 'Commercial Cleaning Liquid 5L',
          quantity: 1,
          unitPrice: 1180.0,
          total: 1180.0,
          costPrice: 800.0,
          taxStatus: 'taxable',
          taxRate: 18.0,
          taxAmount: 180.0,
          taxableAmount: 1000.0,
        ),
      ];

      final settings = AppSettings(
        shopName: 'SuperMart Colombo',
        shopAddress: '123 Galle Road, Colombo 03',
        shopPhone: '+94 11 234 5678',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you for shopping with us!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: 'QB001',
        isVatEnabled: true,
        isVatRegistered: true,
        taxIdentificationNumber: '102345678',
        vatRegistrationNumber: '102345678-7000',
        defaultVatRate: 18.0,
        vatPricingType: 'inclusive',
        vatInvoiceMode: 'tax_invoice',
        receiptLanguage: 'en',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptWidget(
                sale: sale,
                items: items,
                settings: settings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Tax Invoice Header is rendered
      expect(find.text('TAX INVOICE'), findsOneWidget);

      // Verify Business TIN and VAT Reg No
      expect(find.textContaining('102345678'), findsWidgets);
      expect(find.textContaining('102345678-7000'), findsWidgets);

      // Verify Customer TIN and VAT Reg No
      expect(find.textContaining('998877665-TIN'), findsOneWidget);
      expect(find.textContaining('998877665-7000'), findsOneWidget);

      // Verify Tax Breakdown Lines
      expect(find.text('Taxable Base'), findsOneWidget);
      expect(find.textContaining('Tax (VAT) (18%'), findsOneWidget);
    });

    testWidgets('Normal POS Receipt does not show TAX INVOICE banner when in normal mode', (tester) async {
      final sale = Sale(
        id: 2,
        billNumber: 'REC-002',
        total: 500.0,
        tax: 0.0,
        isVatEnabled: false,
        invoiceType: 'normal',
        itemsCount: 1,
        paymentMethod: 'cash',
        createdAt: DateTime(2026, 9, 15, 14, 30),
      );

      final items = [
        SaleItem(
          saleId: 2,
          productId: 11,
          productName: 'Biscuits',
          quantity: 2,
          unitPrice: 250.0,
          total: 500.0,
          costPrice: 180.0,
        ),
      ];

      final settings = AppSettings(
        shopName: 'SuperMart Colombo',
        shopAddress: '123 Galle Road, Colombo 03',
        shopPhone: '+94 11 234 5678',
        lowStockThreshold: 5,
        receiptFooter: 'Thank you!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: 'QB001',
        isVatEnabled: false,
        isVatRegistered: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptWidget(
                sale: sale,
                items: items,
                settings: settings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure "TAX INVOICE" is NOT present
      expect(find.text('TAX INVOICE'), findsNothing);
      expect(find.text('TAX SUMMARY / VAT BREAKDOWN'), findsNothing);
    });
  });
}

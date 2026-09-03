import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/product_selling_mode.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/services/sinhala_search_service.dart';
import 'package:quickbill/services/unit_conversion_service.dart';

void main() {
  group('Product Multi-Selling Mode Architecture', () {
    final sugarProduct = Product(
      id: 101,
      name: 'සීනි',
      nameSinhala: 'සීනි',
      nameEnglish: 'Sugar',
      unit: 'kg',
      price: 250.0, // Rs. 250 / kg loose
      costPrice: 220.0, // Rs. 220 / kg cost
      stock: 20.0, // 20 kg in stock
      allowLoose: true,
      allowPack: true,
      packPrice: 270.0, // Rs. 270 / 1kg pack
      packCostPrice: 235.0,
      packSize: 1.0,
      packUnit: 'pack',
      packSizeUnit: 'kg',
    );

    test('Product detects multiple selling modes accurately', () {
      expect(sugarProduct.hasMultipleSellingModes, isTrue);
      expect(sugarProduct.sellingModes.length, 2);

      final looseMode = sugarProduct.sellingModes.firstWhere((m) => m.id == 'loose');
      expect(looseMode.modeType, 'weight');
      expect(looseMode.price, 250.0);

      final packMode = sugarProduct.sellingModes.firstWhere((m) => m.id == 'pack');
      expect(packMode.modeType, 'pack');
      expect(packMode.packSize, 1.0);
      expect(packMode.packSizeUnit, 'kg');
      expect(packMode.price, 270.0);
    });

    test('Sale 1: Sells 1 pack of 1kg sugar @ Rs. 270', () {
      final packCartItem = CartItem(
        product: sugarProduct,
        quantity: 1.0,
        selectedUnit: 'pack',
        sellingMode: 'pack',
        packSize: 1.0,
        packSizeUnit: 'kg',
        customSellingPrice: 270.0,
      );

      expect(packCartItem.itemPrice, 270.0);
      expect(packCartItem.total, 270.0);
      expect(packCartItem.baseQuantity, 1.0); // Deducts 1.0 kg from base inventory
      expect(packCartItem.formattedQuantity, '1 pack');
      expect(packCartItem.rateDisplay, 'Rs. 270.00 / pack');

      // Remaining stock from 20kg
      final remainingStock = sugarProduct.stock - packCartItem.baseQuantity;
      expect(remainingStock, 19.0);
    });

    test('Sale 2: Sells 500g loose sugar @ Rs. 250/kg', () {
      final looseCartItem = CartItem(
        product: sugarProduct,
        quantity: 500.0,
        selectedUnit: 'g',
        sellingMode: 'weight',
      );

      expect(looseCartItem.itemPrice, 250.0);
      expect(looseCartItem.total, 125.0); // 0.5 * 250 = 125.0
      expect(looseCartItem.baseQuantity, 0.5); // Deducts 0.5 kg from base inventory
      expect(looseCartItem.formattedQuantity, '500g');
      expect(looseCartItem.rateDisplay, 'Rs. 250.00 / kg');

      // Starting from 19kg, remaining is 18.5kg
      final remainingStock = 19.0 - looseCartItem.baseQuantity;
      expect(remainingStock, 18.5);
    });

    test('Sale 3: Sells 250g loose sugar @ Rs. 250/kg', () {
      final looseCartItem = CartItem(
        product: sugarProduct,
        quantity: 250.0,
        selectedUnit: 'g',
        sellingMode: 'weight',
      );

      expect(looseCartItem.itemPrice, 250.0);
      expect(looseCartItem.total, 62.5); // 0.25 * 250 = 62.5
      expect(looseCartItem.baseQuantity, 0.25); // Deducts 0.25 kg from base inventory
      expect(looseCartItem.formattedQuantity, '250g');

      // Starting from 18.5kg, remaining is 18.25kg
      final remainingStock = 18.5 - looseCartItem.baseQuantity;
      expect(remainingStock, 18.25);
    });

    test('Sale 4: Sells 2 packs of 1kg sugar @ Rs. 270/pack', () {
      final packCartItem = CartItem(
        product: sugarProduct,
        quantity: 2.0,
        selectedUnit: 'pack',
        sellingMode: 'pack',
        packSize: 1.0,
        packSizeUnit: 'kg',
        customSellingPrice: 270.0,
      );

      expect(packCartItem.itemPrice, 270.0);
      expect(packCartItem.total, 540.0); // 2 * 270 = 540.0
      expect(packCartItem.baseQuantity, 2.0); // Deducts 2.0 kg from base inventory
      expect(packCartItem.formattedQuantity, '2 packs');
    });

    test('Sale 5: Sells 2 packs of 500g sugar @ Rs. 140/pack', () {
      final halfKgPackCartItem = CartItem(
        product: sugarProduct,
        quantity: 2.0,
        selectedUnit: 'pack',
        sellingMode: 'pack',
        packSize: 0.5, // 500g = 0.5kg
        packSizeUnit: 'kg',
        customSellingPrice: 140.0,
      );

      expect(halfKgPackCartItem.itemPrice, 140.0);
      expect(halfKgPackCartItem.total, 280.0); // 2 * 140 = 280.0
      expect(halfKgPackCartItem.baseQuantity, 1.0); // 2 * 0.5kg = 1.0kg deduction
      expect(halfKgPackCartItem.formattedQuantity, '2 packs');
    });

    test('Sale 6: Sells custom decimal weight 630g sugar @ Rs. 250/kg', () {
      final customCartItem = CartItem(
        product: sugarProduct,
        quantity: 630.0,
        selectedUnit: 'g',
        sellingMode: 'weight',
      );

      expect(customCartItem.itemPrice, 250.0);
      expect(customCartItem.total, 157.5); // 0.63 * 250 = 157.5
      expect(customCartItem.baseQuantity, 0.63);
      expect(customCartItem.formattedQuantity, '630g');
    });

    test('Smart Search Query Parsing identifies product, mode, quantity, and unit', () {
      // 1. Loose / Weight search queries
      final q1 = SinhalaSearchService.parseSearchQuery('sini 500g');
      expect(q1.productQuery, 'sini');
      expect(q1.quantity, 500.0);
      expect(q1.unit, 'g');
      expect(q1.sellingMode, 'weight');

      final q2 = SinhalaSearchService.parseSearchQuery('rice 2kg');
      expect(q2.productQuery, 'rice');
      expect(q2.quantity, 2.0);
      expect(q2.unit, 'kg');
      expect(q2.sellingMode, 'weight');

      // 2. Pack search queries
      final q3 = SinhalaSearchService.parseSearchQuery('sini 1 pack');
      expect(q3.productQuery, 'sini');
      expect(q3.quantity, 1.0);
      expect(q3.unit, 'pack');
      expect(q3.sellingMode, 'pack');

      final q4 = SinhalaSearchService.parseSearchQuery('sini 2 packs');
      expect(q4.productQuery, 'sini');
      expect(q4.quantity, 2.0);
      expect(q4.unit, 'packs');
      expect(q4.sellingMode, 'pack');

      // 3. Count / Liquid queries
      final q5 = SinhalaSearchService.parseSearchQuery('kiri 500ml');
      expect(q5.productQuery, 'kiri');
      expect(q5.quantity, 500.0);
      expect(q5.unit, 'ml');
      expect(q5.sellingMode, 'liquid');

      final q6 = SinhalaSearchService.parseSearchQuery('1 dozen eggs');
      expect(q6.productQuery, 'eggs');
      expect(q6.quantity, 1.0);
      expect(q6.unit, 'dozen');
      expect(q6.sellingMode, 'piece');
    });

    test('SaleItem serialization records selling_mode and pack_size immutably', () {
      final saleItem = SaleItem(
        saleId: 10,
        productId: 101,
        productName: 'සීනි',
        quantity: 1.0, // 1.0 kg deducted
        unitPrice: 270.0,
        total: 270.0,
        costPrice: 235.0,
        soldUnit: 'pack',
        soldQuantity: 1.0,
        sellingMode: 'pack',
        packSize: 1.0,
      );

      final map = saleItem.toMap();
      expect(map['selling_mode'], 'pack');
      expect(map['sold_unit'], 'pack');
      expect(map['sold_quantity'], 1.0);
      expect(map['pack_size'], 1.0);
      expect(map['total'], 270.0);

      final reconstructed = SaleItem.fromMap(map);
      expect(reconstructed.sellingMode, 'pack');
      expect(reconstructed.soldUnit, 'pack');
      expect(reconstructed.formattedQuantity, '1 pack');
    });
  });
}

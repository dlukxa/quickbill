import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/price_history.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/services/sinhala_search_service.dart';
import 'package:quickbill/services/unit_conversion_service.dart';

void main() {
  group('UnitConversionService — Strict Measurement Categories & Unit Isolation', () {
    test('Strictly isolates compatible units by measurement category', () {
      // WEIGHT -> only kg, g
      final weightUnits = UnitConversionService.getCompatibleUnits('kg');
      expect(weightUnits, containsAll(['kg', 'g']));
      expect(weightUnits.contains('pcs'), isFalse);
      expect(weightUnits.contains('bottle'), isFalse);

      // LIQUID -> only L, ml
      final liquidUnits = UnitConversionService.getCompatibleUnits('L');
      expect(liquidUnits, containsAll(['L', 'ml']));
      expect(liquidUnits.contains('kg'), isFalse);
      expect(liquidUnits.contains('box'), isFalse);

      // COUNT -> only pcs, dozen
      final countUnits = UnitConversionService.getCompatibleUnits('pcs');
      expect(countUnits, containsAll(['pcs', 'dozen']));
      expect(countUnits.contains('bottle'), isFalse);
      expect(countUnits.contains('kg'), isFalse);

      // PACKAGING -> only packaging units
      final bottleUnits = UnitConversionService.getCompatibleUnits('bottle');
      expect(bottleUnits, equals(['bottle']));

      final packUnits = UnitConversionService.getCompatibleUnits('pack');
      expect(packUnits, containsAll(['pack', 'box']));
      expect(packUnits.contains('kg'), isFalse);

      // LENGTH -> only m, cm
      final lengthUnits = UnitConversionService.getCompatibleUnits('m');
      expect(lengthUnits, containsAll(['m', 'cm']));
    });

    test('Converts grams to kilograms and vice-versa accurately', () {
      expect(UnitConversionService.convertToBaseQuantity(500, 'g', 'kg'), 0.5);
      expect(UnitConversionService.convertToBaseQuantity(250, 'g', 'kg'), 0.25);
      expect(UnitConversionService.convertToBaseQuantity(750, 'g', 'kg'), 0.75);
      expect(UnitConversionService.convertToBaseQuantity(1.5, 'kg', 'kg'), 1.5);
      expect(UnitConversionService.convertFromBaseQuantity(0.5, 'g', 'kg'), 500.0);
      expect(UnitConversionService.convertFromBaseQuantity(1.25, 'g', 'kg'), 1250.0);
    });

    test('Calculates variable quantity selling price (500g of sugar at Rs. 250/kg)', () {
      final linePrice = UnitConversionService.calculateLinePrice(
        250.0, // Rs. 250 per kg
        500.0, // 500g
        'g',
        'kg',
      );
      expect(linePrice, 125.0);
    });

    test('Calculates exact custom decimal quantities (630g, 750g, 1.5kg of sugar at Rs. 250/kg)', () {
      // 500g -> Rs. 125.00
      expect(UnitConversionService.calculateLinePrice(250.0, 500.0, 'g', 'kg'), 125.0);

      // 750g -> Rs. 187.50
      expect(UnitConversionService.calculateLinePrice(250.0, 750.0, 'g', 'kg'), 187.5);

      // 1.5kg -> Rs. 375.00
      expect(UnitConversionService.calculateLinePrice(250.0, 1.5, 'kg', 'kg'), 375.0);

      // 630g -> Rs. 157.50
      expect(UnitConversionService.calculateLinePrice(250.0, 630.0, 'g', 'kg'), 157.5);
    });

    test('Calculates variable quantity cost and profit (500g sugar, cost Rs. 220/kg, price Rs. 250/kg)', () {
      final profitMap = UnitConversionService.calculateProfitAndMargin(
        pricePerBaseUnit: 250.0,
        costPerBaseUnit: 220.0,
        quantity: 500.0,
        soldUnit: 'g',
        productBaseUnit: 'kg',
      );

      expect(profitMap['profit'], 15.0); // (125.0 - 110.0)
      expect(profitMap['marginPercent'], 12.0); // (15 / 125) * 100
    });

    test('Calculates liquid volume prices (250ml coconut oil at Rs. 800/L)', () {
      final price = UnitConversionService.calculateLinePrice(800.0, 250.0, 'ml', 'L');
      expect(price, 200.0);

      final cost = UnitConversionService.calculateLineCost(600.0, 250.0, 'ml', 'L');
      expect(cost, 150.0);
    });

    test('Calculates count prices (1 dozen eggs at Rs. 40/pc)', () {
      final price = UnitConversionService.calculateLinePrice(40.0, 1.0, 'dozen', 'pcs');
      expect(price, 480.0); // 12 * 40
    });

    test('Formats natural Sri Lankan phrasing across all product types', () {
      // Piece
      expect(UnitConversionService.formatNaturalQuantity(1, 'piece'), '1 piece');
      expect(UnitConversionService.formatNaturalQuantity(2, 'piece'), '2 pieces');
      expect(UnitConversionService.formatNaturalQuantity(6, 'pcs'), '6 pieces');

      // Weight
      expect(UnitConversionService.formatNaturalQuantity(500, 'g'), '500 g');
      expect(UnitConversionService.formatNaturalQuantity(1.25, 'kg'), '1.25 kg');
      expect(UnitConversionService.formatNaturalQuantity(2, 'kg'), '2 kg');

      // Liquid
      expect(UnitConversionService.formatNaturalQuantity(500, 'ml'), '500 ml');
      expect(UnitConversionService.formatNaturalQuantity(1, 'L'), '1 L');
      expect(UnitConversionService.formatNaturalQuantity(1.5, 'L'), '1.5 L');

      // Pack & Box & Dozen
      expect(UnitConversionService.formatNaturalQuantity(1, 'pack'), '1 pack');
      expect(UnitConversionService.formatNaturalQuantity(2, 'pack'), '2 packs');
      expect(UnitConversionService.formatNaturalQuantity(1, 'box'), '1 box');
      expect(UnitConversionService.formatNaturalQuantity(2, 'box'), '2 boxes');
      expect(UnitConversionService.formatNaturalQuantity(1, 'dozen'), '1 dozen');
      expect(UnitConversionService.formatNaturalQuantity(2, 'dozen'), '2 dozen');
    });

    test('Provides appropriate retail step sizes for quantity increment / decrement', () {
      // Grams step
      expect(UnitConversionService.getStepIncrement(50, 'g'), 50.0);
      expect(UnitConversionService.getStepIncrement(250, 'g'), 100.0);
      expect(UnitConversionService.getStepIncrement(500, 'g'), 250.0);
      expect(UnitConversionService.getStepDecrement(500, 'g'), 100.0);
      expect(UnitConversionService.getStepDecrement(750, 'g'), 250.0);

      // Kg step
      expect(UnitConversionService.getStepIncrement(0.5, 'kg'), 0.25);
      expect(UnitConversionService.getStepIncrement(1.0, 'kg'), 0.5);

      // Piece step
      expect(UnitConversionService.getStepIncrement(1, 'pcs'), 1.0);
      expect(UnitConversionService.getStepDecrement(2, 'pcs'), 1.0);
    });
  });

  group('SmartQueryParser — Quantity & Unit Extraction from Cashier Search', () {
    test('Extracts trailing quantity and unit from English & Singlish inputs', () {
      final q1 = SinhalaSearchService.parseSearchQuery('sini 500g');
      expect(q1.hasQuantitySpec, isTrue);
      expect(q1.productQuery, 'sini');
      expect(q1.quantity, 500.0);
      expect(q1.unit, 'g');

      final q2 = SinhalaSearchService.parseSearchQuery('sugar 1.5kg');
      expect(q2.hasQuantitySpec, isTrue);
      expect(q2.productQuery, 'sugar');
      expect(q2.quantity, 1.5);
      expect(q2.unit, 'kg');

      final q3 = SinhalaSearchService.parseSearchQuery('kiri 500ml');
      expect(q3.hasQuantitySpec, isTrue);
      expect(q3.productQuery, 'kiri');
      expect(q3.quantity, 500.0);
      expect(q3.unit, 'ml');

      final q4 = SinhalaSearchService.parseSearchQuery('rice 2kg');
      expect(q4.hasQuantitySpec, isTrue);
      expect(q4.productQuery, 'rice');
      expect(q4.quantity, 2.0);
      expect(q4.unit, 'kg');
    });

    test('Extracts quantity and unit from Sinhala inputs', () {
      final q = SinhalaSearchService.parseSearchQuery('සීනි 500g');
      expect(q.hasQuantitySpec, isTrue);
      expect(q.productQuery, 'සීනි');
      expect(q.quantity, 500.0);
      expect(q.unit, 'g');
    });

    test('Handles leading quantity notation (e.g. "500g dhal", "1 dozen eggs")', () {
      final q1 = SinhalaSearchService.parseSearchQuery('500g dhal');
      expect(q1.hasQuantitySpec, isTrue);
      expect(q1.productQuery, 'dhal');
      expect(q1.quantity, 500.0);
      expect(q1.unit, 'g');

      final q2 = SinhalaSearchService.parseSearchQuery('1 dozen eggs');
      expect(q2.hasQuantitySpec, isTrue);
      expect(q2.productQuery, 'eggs');
      expect(q2.quantity, 1.0);
      expect(q2.unit, 'dozen');
    });

    test('Ranks product accurately even when query includes quantity spec', () {
      final sugar = Product(id: 1, name: 'Sugar', nameSinhala: 'සීනි', price: 250.0, unit: 'kg');
      final tea = Product(id: 2, name: 'Tea', nameSinhala: 'තේ', price: 150.0, unit: 'pcs');

      final results = SinhalaSearchService.filterAndRank([sugar, tea], 'sini 500g');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.nameSinhala, 'සීනි');
    });
  });

  group('CartItem & SaleItem — Fractional Billing & Formatting', () {
    test('CartItem correctly computes baseQuantity and line total for 500g sugar', () {
      final sugar = Product(
        id: 1,
        name: 'White Sugar',
        nameSinhala: 'සුදු සීනි',
        price: 250.0,
        costPrice: 220.0,
        stock: 50.0,
        unit: 'kg',
      );

      final cartItem = CartItem(
        product: sugar,
        quantity: 500.0,
        selectedUnit: 'g',
      );

      expect(cartItem.itemUnit, 'g');
      expect(cartItem.baseQuantity, 0.5);
      expect(cartItem.total, 125.0);
      expect(cartItem.formattedQuantity, '500g');
      expect(cartItem.naturalQuantity, '500 g');
      expect(cartItem.rateDisplay, 'Rs. 250.00 / kg');
    });

    test('SaleItem preserves exact snapshot price, cost, and formatted quantity', () {
      final saleItem = SaleItem(
        saleId: 101,
        productId: 1,
        productName: 'White Sugar',
        quantity: 0.5, // 0.5kg base quantity
        unitPrice: 250.0, // Rs. 250 / kg
        costPrice: 220.0,
        total: 125.0,
        soldQuantity: 500.0,
        soldUnit: 'g',
      );

      expect(saleItem.quantity, 0.5);
      expect(saleItem.unitPrice, 250.0);
      expect(saleItem.total, 125.0);
      expect(saleItem.formattedQuantity, '500g');
    });
  });

  group('PriceHistory Model & Serialization', () {
    test('Calculates price difference and serialization correctly', () {
      final history = PriceHistory(
        productId: 1,
        branchId: 1,
        oldPrice: 250.0,
        newPrice: 270.0,
        oldCostPrice: 220.0,
        newCostPrice: 240.0,
        oldUnit: 'kg',
        newUnit: 'kg',
        reason: 'Market wholesale hike',
        changedBy: 'Admin',
      );

      expect(history.priceDifference, 20.0);
      expect(history.isIncrease, isTrue);

      final map = history.toMap();
      final fromMap = PriceHistory.fromMap(map);

      expect(fromMap.oldPrice, 250.0);
      expect(fromMap.newPrice, 270.0);
      expect(fromMap.reason, 'Market wholesale hike');
    });
  });
}

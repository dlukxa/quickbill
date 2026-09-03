import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/services/unit_conversion_service.dart';

void main() {
  group('Stock Adding & Inventory Receiving Calculations', () {
    final sugarProduct = Product(
      id: 201,
      name: 'සීනි',
      nameSinhala: 'සීනි',
      nameEnglish: 'White Sugar',
      unit: 'kg',
      price: 250.0,
      costPrice: 220.0,
      stock: 20.0, // 20kg initial
    );

    final oilProduct = Product(
      id: 202,
      name: 'පොල් තෙල්',
      nameSinhala: 'පොල් තෙල්',
      nameEnglish: 'Coconut Oil',
      unit: 'L',
      price: 800.0,
      costPrice: 650.0,
      stock: 15.0, // 15L initial
    );

    final eggProduct = Product(
      id: 203,
      name: 'බිත්තර',
      nameSinhala: 'බිත්තර',
      nameEnglish: 'Eggs',
      unit: 'pcs',
      price: 40.0,
      stock: 30.0, // 30 pcs initial
    );

    test('Direct Restock: Adds standard 50kg wholesale bag of sugar', () {
      final addedBase = UnitConversionService.convertToBaseQuantity(50.0, 'kg', sugarProduct.baseUnit);
      expect(addedBase, 50.0);
      final newStock = sugarProduct.stock + addedBase;
      expect(newStock, 70.0);
      expect(UnitConversionService.formatHumanReadableQuantity(newStock, sugarProduct.baseUnit), '70 kg');
    });

    test('Direct Restock: Adds 500g fractional sample to sugar stock', () {
      final addedBase = UnitConversionService.convertToBaseQuantity(500.0, 'g', sugarProduct.baseUnit);
      expect(addedBase, 0.5);
      final newStock = sugarProduct.stock + addedBase;
      expect(newStock, 20.5);
      expect(UnitConversionService.formatHumanReadableQuantity(newStock, sugarProduct.baseUnit), '20.5 kg');
    });

    test('Direct Restock: Adds 20L can to coconut oil stock', () {
      final addedBase = UnitConversionService.convertToBaseQuantity(20.0, 'L', oilProduct.baseUnit);
      expect(addedBase, 20.0);
      final newStock = oilProduct.stock + addedBase;
      expect(newStock, 35.0);
      expect(UnitConversionService.formatHumanReadableQuantity(newStock, oilProduct.baseUnit), '35 L');
    });

    test('Direct Restock: Adds 2 dozen eggs to stock', () {
      final addedBase = UnitConversionService.convertToBaseQuantity(2.0, 'dozen', eggProduct.baseUnit);
      expect(addedBase, 24.0); // 2 * 12 = 24 pcs
      final newStock = eggProduct.stock + addedBase;
      expect(newStock, 54.0);
      expect(UnitConversionService.formatHumanReadableQuantity(newStock, eggProduct.baseUnit), '54 pcs');
    });

    test('Package Multiplier Restock: Receives 20 × 1kg packs of sugar', () {
      const packCount = 20.0;
      const packSize = 1.0;
      const packSizeUnit = 'kg';

      final sizeInBase = UnitConversionService.convertToBaseQuantity(packSize, packSizeUnit, sugarProduct.baseUnit);
      final totalAddedBase = packCount * sizeInBase;

      expect(totalAddedBase, 20.0);
      final newStock = sugarProduct.stock + totalAddedBase;
      expect(newStock, 40.0);
    });

    test('Package Multiplier Restock: Receives 10 × 500g packs of sugar', () {
      const packCount = 10.0;
      const packSize = 500.0;
      const packSizeUnit = 'g';

      final sizeInBase = UnitConversionService.convertToBaseQuantity(packSize, packSizeUnit, sugarProduct.baseUnit);
      final totalAddedBase = packCount * sizeInBase;

      expect(totalAddedBase, 5.0); // 10 * 0.5kg = 5.0kg
      final newStock = sugarProduct.stock + totalAddedBase;
      expect(newStock, 25.0);
    });

    test('Package Multiplier Restock: Receives 5 × 20L cans of oil', () {
      const packCount = 5.0;
      const packSize = 20.0;
      const packSizeUnit = 'L';

      final sizeInBase = UnitConversionService.convertToBaseQuantity(packSize, packSizeUnit, oilProduct.baseUnit);
      final totalAddedBase = packCount * sizeInBase;

      expect(totalAddedBase, 100.0); // 5 * 20L = 100.0L
      final newStock = oilProduct.stock + totalAddedBase;
      expect(newStock, 115.0);
    });
  });
}

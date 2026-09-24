import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/category_translations.dart';

void main() {
  group('Category Translations Tests', () {
    test('Translates English categories to Sinhala including General and Uncategorized', () {
      expect(CategoryTranslations.translate('General', 'si'), 'පොදු / වෙනත්');
      expect(CategoryTranslations.translate('Uncategorized', 'si'), 'වර්ගීකරණය නොකළ');
      expect(CategoryTranslations.translate('Beverages', 'si'), 'බීම වර්ග');
      expect(CategoryTranslations.translate('Food & Grocery', 'si'), 'ආහාර සහ සිල්ලර බඩු');
    });
  });

  group('Inventory Audit & Stock Reconciliation Tests', () {
    test('Calculates margin percentage and variance correctly', () {
      const price = 250.0;
      const cost = 180.0;
      final margin = price - cost;
      final marginPct = (margin / price) * 100;

      expect(margin, 70.0);
      expect(marginPct.toStringAsFixed(1), '28.0');

      const systemStock = 15.0;
      const physicalStock = 12.0;
      const variance = physicalStock - systemStock;
      final varianceValue = variance * cost;

      expect(variance, -3.0);
      expect(varianceValue, -540.0); // Loss of Rs. 540
    });
  });
}

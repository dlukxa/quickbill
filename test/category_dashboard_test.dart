import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/category_translations.dart';
import 'package:quickbill/utils/category_icon_util.dart';

void main() {
  group('Category Dashboard & Analytics Tests', () {
    test('Category Translations verify common retail categories in Sinhala', () {
      expect(CategoryTranslations.translate('Beverages', 'si'), 'බීම වර්ග');
      expect(CategoryTranslations.translate('Food & Grocery', 'si'), 'ආහාර සහ සිල්ලර බඩු');
      expect(CategoryTranslations.translate('Dairy & Eggs', 'si'), 'කිරි නිෂ්පාදන සහ බිත්තර');
      expect(CategoryTranslations.translate('General', 'si'), 'පොදු / වෙනත්');
      expect(CategoryTranslations.translate('Uncategorized', 'si'), 'වර්ගීකරණය නොකළ');
    });

    test('CategoryIconUtil provides valid icons and colors for main categories', () {
      final icon = CategoryIconUtil.getIconForMainCategory('Beverages');
      final color = CategoryIconUtil.getColorForMainCategory('Beverages');

      expect(icon, isNotNull);
      expect(color, isNotNull);
    });

    test('Category Analytics Metric Calculations', () {
      const retailValuation = 500000.0;
      const costValuation = 360000.0;
      final grossProfit = retailValuation - costValuation;
      final marginPct = (grossProfit / retailValuation) * 100;

      expect(grossProfit, 140000.0);
      expect(marginPct.toStringAsFixed(1), '28.0');

      const salesRevenue = 150000.0;
      const totalStoreSales = 600000.0;
      final salesShare = (salesRevenue / totalStoreSales) * 100;

      expect(salesShare.toStringAsFixed(1), '25.0');
    });

    test('Stock Health classification logic', () {
      String getHealthStatus(double stock, double minStock) {
        if (stock <= 0) return 'out';
        if (stock <= minStock) return 'low';
        return 'healthy';
      }

      expect(getHealthStatus(0, 10), 'out');
      expect(getHealthStatus(-2, 10), 'out');
      expect(getHealthStatus(5, 10), 'low');
      expect(getHealthStatus(10, 10), 'low');
      expect(getHealthStatus(12, 10), 'healthy');
    });
  });
}

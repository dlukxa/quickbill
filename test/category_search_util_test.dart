import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/category_search_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategorySearchUtil Singlish & Multilingual Tests', () {
    test('Matches Singlish "kiri" to Dairy & Eggs, Milk, and related items', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('kiri');
      expect(matchingMain, contains('Dairy & Eggs'));

      final matchingSub = CategorySearchUtil.filterSubcategories('kiri');
      expect(matchingSub, contains('Milk'));
      expect(matchingSub, contains('Milk Drinks & Shakes'));
      expect(matchingSub, contains('Condensed & Evaporated Milk'));
    });

    test('Matches Singlish "parippu" or "dhal" to Dal & Pulses', () {
      final matchingSub1 = CategorySearchUtil.filterSubcategories('parippu');
      expect(matchingSub1, contains('Dal & Pulses'));

      final matchingSub2 = CategorySearchUtil.filterSubcategories('dhal');
      expect(matchingSub2, contains('Dal & Pulses'));
    });

    test('Matches Singlish "mas" and "kukul mas" to Meat categories', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('mas');
      expect(matchingMain, contains('Meat & Seafood'));

      final matchingSub = CategorySearchUtil.filterSubcategories('kukul mas');
      expect(matchingSub, contains('Chicken & Poultry'));
    });

    test('Matches Singlish "malu" or "maalu" to Fish & Seafood', () {
      final matchingSub1 = CategorySearchUtil.filterSubcategories('malu');
      expect(matchingSub1, contains('Fish & Seafood'));

      final matchingSub2 = CategorySearchUtil.filterSubcategories('maalu');
      expect(matchingSub2, contains('Fish & Seafood'));
    });

    test('Matches Singlish "biththara" or "bittara" to Eggs', () {
      final matchingSub = CategorySearchUtil.filterSubcategories('biththara');
      expect(matchingSub, contains('Eggs'));

      final matchingMain = CategorySearchUtil.filterMainCategories('bittara');
      expect(matchingMain, contains('Dairy & Eggs'));
    });

    test('Matches Singlish "elawalu" to Fruits & Vegetables', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('elawalu');
      expect(matchingMain, contains('Fruits & Vegetables'));
    });

    test('Matches Singlish "palathuru" to Fruits & Vegetables', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('palathuru');
      expect(matchingMain, contains('Fruits & Vegetables'));
    });

    test('Matches Singlish "pan" or "paan" to Bread & Bakery', () {
      final matchingSub = CategorySearchUtil.filterSubcategories('pan');
      expect(matchingSub, contains('Bread & Bakery'));

      final matchingMain = CategorySearchUtil.filterMainCategories('paan');
      expect(matchingMain, contains('Bakery & Snacks'));
    });

    test('Matches Singlish "seeni" or "sini" to Salt, Sugar & Jaggery', () {
      final matchingSub1 = CategorySearchUtil.filterSubcategories('seeni');
      expect(matchingSub1, contains('Salt, Sugar & Jaggery'));

      final matchingSub2 = CategorySearchUtil.filterSubcategories('sini');
      expect(matchingSub2, contains('Salt, Sugar & Jaggery'));
    });

    test('Matches Singlish "the" / "thee" and "kopi" to Tea & Coffee', () {
      final matchingSub1 = CategorySearchUtil.filterSubcategories('the');
      expect(matchingSub1, contains('Tea & Coffee'));

      final matchingSub2 = CategorySearchUtil.filterSubcategories('kopi');
      expect(matchingSub2, contains('Tea & Coffee'));
    });

    test('Matches Singlish "tel" / "thel" to Cooking Oils & Fats', () {
      final matchingSub = CategorySearchUtil.filterSubcategories('tel');
      expect(matchingSub, contains('Cooking Oils & Fats'));
    });

    test('Matches Singlish "bima" / "beema" to Beverages and Soft Drinks', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('bima');
      expect(matchingMain, contains('Beverages'));

      final matchingSub = CategorySearchUtil.filterSubcategories('beema');
      expect(matchingSub, contains('Soft Drinks & Sodas'));
    });

    test('Matches Singlish "beheth" to Health & Medicine', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('beheth');
      expect(matchingMain, contains('Health & Medicine'));
    });

    test('Matches Sinhala Unicode script directly', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('කිරි');
      expect(matchingMain, contains('Dairy & Eggs'));

      final matchingSub = CategorySearchUtil.filterSubcategories('බිත්තර');
      expect(matchingSub, contains('Eggs'));
    });

    test('Matches standard English queries', () {
      final matchingMain = CategorySearchUtil.filterMainCategories('Beverages');
      expect(matchingMain, contains('Beverages'));

      final matchingSub = CategorySearchUtil.filterSubcategories('Noodles');
      expect(matchingSub, contains('Noodles & Pasta'));
    });

    test('Empty query returns all categories', () {
      final allMain = CategorySearchUtil.filterMainCategories('');
      expect(allMain.length, equals(28));
    });
  });
}

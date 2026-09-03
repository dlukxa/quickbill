import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/services/sinhala_search_service.dart';

void main() {
  group('SinhalaSearchService Transliteration Tests', () {
    test('Common Singlish words transliteration', () {
      expect(SinhalaSearchService.singlishToSinhala('kiri the'), 'කිරි තේ');
      expect(SinhalaSearchService.singlishToSinhala('kiri bath'), 'කිරිබත්');
      expect(SinhalaSearchService.singlishToSinhala('seeni'), 'සීනි');
      expect(SinhalaSearchService.singlishToSinhala('sini'), 'සීනි');
      expect(SinhalaSearchService.singlishToSinhala('paan'), 'පාන්');
      expect(SinhalaSearchService.singlishToSinhala('pol thel'), 'පොල් තෙල්');
      expect(SinhalaSearchService.singlishToSinhala('kukul mas'), 'කුකුල් මස්');
      expect(SinhalaSearchService.singlishToSinhala('biththara'), 'බිත්තර');
    });

    test('Sinhala detection', () {
      expect(SinhalaSearchService.isSinhala('කිරි තේ'), isTrue);
      expect(SinhalaSearchService.isSinhala('kiri the'), isFalse);
      expect(SinhalaSearchService.isSinhala('Milk Tea 150'), isFalse);
      expect(SinhalaSearchService.isSinhala('කිරි Tea'), isTrue);
    });

    test('generateSearchTokens precomputes rich tokens', () {
      final tokens = SinhalaSearchService.generateSearchTokens(
        name: 'කිරි තේ',
        nameEnglish: 'Milk Tea',
        searchAliases: 'hot tea, the',
        baseBarcode: '4790001234567',
      );
      expect(tokens.contains('කිරි තේ'), isTrue);
      expect(tokens.contains('milk tea'), isTrue);
      expect(tokens.contains('4790001234567'), isTrue);
      expect(tokens.any((t) => t.contains('kiri')), isTrue);
    });
  });

  group('SinhalaSearchService Product Search & Ranking Tests', () {
    final products = [
      Product(
        id: 1,
        name: 'කිරි තේ',
        nameSinhala: 'කිරි තේ',
        nameEnglish: 'Milk Tea',
        searchAliases: 'hot tea, plain the',
        price: 150,
      ),
      Product(
        id: 2,
        name: 'කිරිබත්',
        nameSinhala: 'කිරිබත්',
        nameEnglish: 'Milk Rice',
        price: 250,
      ),
      Product(
        id: 3,
        name: 'සුදු සීනි 1kg',
        nameSinhala: 'සුදු සීනි 1kg',
        nameEnglish: 'White Sugar 1kg',
        price: 280,
      ),
      Product(
        id: 4,
        name: 'රතු කැකුළු 5kg',
        nameSinhala: 'රතු කැකුළු 5kg',
        nameEnglish: 'Red Raw Rice 5kg',
        price: 1100,
      ),
      Product(
        id: 5,
        name: 'පාන්',
        nameSinhala: 'පාන්',
        nameEnglish: 'Bread',
        price: 140,
      ),
      Product(
        id: 6,
        name: 'Anchor Milk Powder 400g',
        nameSinhala: 'ඇන්කර් කිරිපිටි 400g',
        baseBarcode: '8850123456789',
        price: 1150,
      ),
    ];

    test('Singlish query "kiri the" finds "කිරි තේ" at top rank', () {
      final results = SinhalaSearchService.filterAndRank(products, 'kiri the');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'කිරි තේ');
    });

    test('Singlish query "kiribath" finds "කිරිබත්" at top rank', () {
      final results = SinhalaSearchService.filterAndRank(products, 'kiribath');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'කිරිබත්');
    });

    test('Singlish query "kiri bath" (with space) finds "කිරිබත්"', () {
      final results = SinhalaSearchService.filterAndRank(products, 'kiri bath');
      expect(results.isNotEmpty, isTrue);
      expect(results.any((p) => p.name == 'කිරිබත්'), isTrue);
    });

    test('Singlish query "seeni" / "sini" finds "සුදු සීනි 1kg"', () {
      final results1 = SinhalaSearchService.filterAndRank(products, 'seeni');
      expect(results1.isNotEmpty, isTrue);
      expect(results1.first.name, 'සුදු සීනි 1kg');

      final results2 = SinhalaSearchService.filterAndRank(products, 'sini');
      expect(results2.isNotEmpty, isTrue);
      expect(results2.first.name, 'සුදු සීනි 1kg');
    });

    test('English query "milk tea" finds "කිරි තේ"', () {
      final results = SinhalaSearchService.filterAndRank(products, 'milk tea');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'කිරි තේ');
    });

    test('Alias query "hot tea" finds "කිරි තේ"', () {
      final results = SinhalaSearchService.filterAndRank(products, 'hot tea');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'කිරි තේ');
    });

    test('Barcode query "8850123456789" finds "Anchor Milk Powder 400g"', () {
      final results = SinhalaSearchService.filterAndRank(products, '8850123456789');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'Anchor Milk Powder 400g');
    });

    test('Sinhala Unicode query "කිරි" finds both "කිරි තේ", "කිරිබත්", and "ඇන්කර් කිරිපිටි 400g"', () {
      final results = SinhalaSearchService.filterAndRank(products, 'කිරි');
      expect(results.length, greaterThanOrEqualTo(3));
      final names = results.map((p) => p.name).toList();
      expect(names.contains('කිරි තේ'), isTrue);
      expect(names.contains('කිරිබත්'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/services/sinhala_transliteration_service.dart';

void main() {
  group('SinhalaTransliterationService Core Tests', () {
    test('Converts required user examples accurately', () {
      expect(SinhalaTransliterationService.transliterate('kiri samba'), equals('කිරි සම්බා'));
      expect(SinhalaTransliterationService.transliterate('kiri'), equals('කිරි'));
      expect(SinhalaTransliterationService.transliterate('seeni'), equals('සීනි'));
      expect(SinhalaTransliterationService.transliterate('sini'), equals('සීනි'));
      expect(SinhalaTransliterationService.transliterate('paen'), equals('පාන්'));
      expect(SinhalaTransliterationService.transliterate('pan'), equals('පාන්'));
      expect(SinhalaTransliterationService.transliterate('bath'), equals('බත්'));
      expect(SinhalaTransliterationService.transliterate('the'), equals('තේ'));
      expect(SinhalaTransliterationService.transliterate('sudu kek'), equals('සුදු කේක්'));
      expect(SinhalaTransliterationService.transliterate('kiribath'), equals('කිරිබත්'));
    });

    test('Preserves quantities, units, and numbers', () {
      expect(SinhalaTransliterationService.transliterate('sudu seeni 1kg'), equals('සුදු සීනි 1kg'));
      expect(SinhalaTransliterationService.transliterate('anchor 400g'), equals('ඇන්කර් 400g'));
      expect(SinhalaTransliterationService.transliterate('kiri 1L'), equals('කිරි 1L'));
      expect(SinhalaTransliterationService.transliterate('biththara 10pcs'), equals('බිත්තර 10pcs'));
    });

    test('Preserves special characters and formatting', () {
      expect(SinhalaTransliterationService.transliterate('kiri - 500ml (special)'), equals('කිරි - 500ml (ස්පෙෂල්)'));
      expect(SinhalaTransliterationService.transliterate('Rs. 150.00 / paan'), equals('Rs. 150.00 / පාන්'));
    });

    test('Generates suggestion correctly for Singlish input', () {
      final suggestion = SinhalaTransliterationService.getSuggestion('kiri samba');
      expect(suggestion, isNotNull);
      expect(suggestion!.converted, equals('කිරි සම්බා'));
      expect(suggestion.hasChange, isTrue);
      expect(suggestion.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Returns null suggestion for already Sinhala text', () {
      final suggestion = SinhalaTransliterationService.getSuggestion('කිරි සම්බා');
      expect(suggestion, isNull);
    });

    test('Identifies Sinhala Unicode correctly', () {
      expect(SinhalaTransliterationService.isSinhala('කිරි සම්බා'), isTrue);
      expect(SinhalaTransliterationService.isSinhala('kiri samba'), isFalse);
      expect(SinhalaTransliterationService.isSinhala('Milk Tea / කිරි තේ'), isTrue);
    });
  });
}

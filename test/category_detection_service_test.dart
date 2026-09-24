import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/services/category_detection_service.dart';

void main() {
  group('CategoryDetectionService - Sinhala & Screenshot Item Detection', () {
    test('Detects flour products from screenshot correctly', () {
      expect(CategoryDetectionService.detectSubcategory('අලි අප්ප පිටි 400g'), 'Flour & Baking');
      expect(CategoryDetectionService.detectCategory('අලි අප්ප පිටි 400g'), 'Food & Grocery');

      expect(CategoryDetectionService.detectSubcategory('අලි ඉඩ්ලි මික්ස් 400g'), 'Flour & Baking');
      expect(CategoryDetectionService.detectCategory('අලි ඉඩ්ලි මික්ස් 400g'), 'Food & Grocery');

      expect(CategoryDetectionService.detectSubcategory('අලි උඳුපිටි 200g'), 'Flour & Baking');
      expect(CategoryDetectionService.detectSubcategory('අලි කඩල පිටි 200g'), 'Flour & Baking');
    });

    test('Detects noodles products from screenshot correctly', () {
      expect(CategoryDetectionService.detectSubcategory('අලි වැකෑස් නූඩ්ල්ස් 800g'), 'Noodles & Pasta');
      expect(CategoryDetectionService.detectCategory('අලි වැකෑස් නූඩ්ල්ස් 800g'), 'Food & Grocery');

      expect(CategoryDetectionService.detectSubcategory('අලි ඩ්‍රයි නූඩ්ල්ස් 400g'), 'Noodles & Pasta');
    });

    test('Detects oil, hair color, and iodex from screenshot correctly', () {
      expect(CategoryDetectionService.detectSubcategory('x ඔයිල් 5ml'), 'Cooking Oils & Fats');
      expect(CategoryDetectionService.detectCategory('x ඔයිල් 5ml'), 'Food & Grocery');

      expect(CategoryDetectionService.detectSubcategory('අහැ හෙයාර් කලර් 50ml'), 'Hair Care');
      expect(CategoryDetectionService.detectCategory('අහැ හෙයාර් කලර් 50ml'), 'Personal Care');

      expect(CategoryDetectionService.detectSubcategory('අයිඩෙක්ස් 5g'), 'OTC Medicines');
      expect(CategoryDetectionService.detectCategory('අයිඩෙක්ස් 5g'), 'Health & Medicine');
    });

    test('Detects staple grocery and FMCG items in Sinhala', () {
      expect(CategoryDetectionService.detectSubcategory('කීරි සම්බා සහල් 5kg'), 'Rice & Grains');
      expect(CategoryDetectionService.detectSubcategory('සුදු සීනි 1kg'), 'Salt, Sugar & Jaggery');
      expect(CategoryDetectionService.detectSubcategory('මයිසූර් පරිප්පු 1kg'), 'Dal & Pulses');
      expect(CategoryDetectionService.detectSubcategory('මිරිස් කුඩු 100g'), 'Spices & Seasonings');
      expect(CategoryDetectionService.detectSubcategory('ලක්ස් සබන් කැටය'), 'Soaps & Body Wash');
      expect(CategoryDetectionService.detectSubcategory('මංචි ක්‍රීම් ක්‍රැකර් 100g'), 'Biscuits & Cookies');
      expect(CategoryDetectionService.detectSubcategory('ඇන්කර් කිරිපිටි 400g'), 'Milk');
      expect(CategoryDetectionService.detectSubcategory('දිල්මා තේ කොළ 100g'), 'Tea & Coffee');
      expect(CategoryDetectionService.detectSubcategory('පැනඩෝල් කාඩ් එක'), 'OTC Medicines');
      expect(CategoryDetectionService.detectSubcategory('සන්ලයිට් සබන් කුඩු 1kg'), 'Detergent & Laundry');
    });

    test('Handles empty and unmatched gracefully', () {
      expect(CategoryDetectionService.detectSubcategory(''), isNull);
      expect(CategoryDetectionService.detectCategory(''), isNull);
      expect(CategoryDetectionService.detectSubcategory('Unknown Random SKU #99'), isNull);
      expect(CategoryDetectionService.detectCategory('Unknown Random SKU #99'), isNull);
    });
  });
}

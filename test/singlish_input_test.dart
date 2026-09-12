import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/services/sinhala_transliteration_service.dart';
import 'package:quickbill/widgets/sinhala_transliteration_input.dart';

void main() {
  group('Singlish Transliteration Engine Tests', () {
    test('Converts customer names, addresses, and expenses', () {
      expect(SinhalaTransliterationService.transliterate('kamal perera'), equals('කමල් පෙරේරා'));
      expect(SinhalaTransliterationService.transliterate('nimal silva'), equals('නිමල් සිල්වා'));
      expect(SinhalaTransliterationService.transliterate('galle road'), equals('ගාලු පාර'));
      expect(SinhalaTransliterationService.transliterate('light bill'), equals('ලයිට් බිල්'));
      expect(SinhalaTransliterationService.transliterate('kiri samba'), equals('කිරි සම්බා'));
      expect(SinhalaTransliterationService.transliterate('seeni 1kg'), equals('සීනි 1kg'));
    });
  });

  group('SinglishTextField & SinhalaConvertSuffix Widget Tests', () {
    testWidgets('Tapping [සිං] suffix converts text to Sinhala', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'kamal perera');
      bool convertedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SinglishTextField(
              controller: controller,
              onConverted: () => convertedCalled = true,
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('kamal perera'), findsOneWidget);
      expect(find.text('සිං'), findsOneWidget);

      // Tap [සිං] button
      await tester.tap(find.text('සිං'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('කමල් පෙරේරා'));
      expect(convertedCalled, isTrue);
    });

    testWidgets('Preserves custom suffix icons alongside [සිං] badge', (WidgetTester tester) async {
      final controller = TextEditingController(text: 'light bill');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SinglishTextField(
              controller: controller,
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.clear, key: Key('clear_icon')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('සිං'), findsOneWidget);
      expect(find.byKey(const Key('clear_icon')), findsOneWidget);

      // Tap [සිං]
      await tester.tap(find.text('සිං'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('ලයිට් බිල්'));
    });

    testWidgets('Live Suggestion Banner displays and Use button applies suggestion', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SinglishTextField(
              controller: controller,
              showSuggestionBanner: true,
            ),
          ),
        ),
      );

      // Initially no banner
      expect(find.text('Use'), findsNothing);

      // Enter Singlish text
      controller.text = 'kiri samba';
      await tester.pumpAndSettle();

      // Banner should appear with suggestion and Use button
      expect(find.text('Use'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('කිරි සම්බා'),
        ),
        findsOneWidget,
      );

      // Tap Use button
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('කිරි සම්බා'));
      expect(find.text('කිරි සම්බා'), findsOneWidget);
      // Banner disappears once applied
      expect(find.text('Use'), findsNothing);
    });

    testWidgets('SinglishTextFormField validates and converts properly in Form', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'galle road');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SinglishTextFormField(
                controller: controller,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      // Validate Form
      expect(formKey.currentState!.validate(), isTrue);

      // Tap [සිං]
      await tester.tap(find.text('සිං'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('ගාලු පාර'));
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}

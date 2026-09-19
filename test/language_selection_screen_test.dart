import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickbill/providers/preference_provider.dart';
import 'package:quickbill/screens/startup/language_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LanguageSelectionScreen renders and updates selection on tap', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).init();

    bool didContinue = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: LanguageSelectionScreen(
            onContinue: () {
              didContinue = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header texts
    expect(find.text('Choose Language'), findsOneWidget);
    expect(find.text('Select your preferred language to continue setting up QuickBill.'), findsOneWidget);

    // Verify language options
    expect(find.text('English'), findsWidgets);
    expect(find.text('Sinhala'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('தமிழ்'), findsOneWidget);

    // Verify Continue button
    expect(find.text('Continue'), findsOneWidget);

    // Tap on Sinhala
    await tester.ensureVisible(find.text('සිංහල'));
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify that language preference was updated to Sinhala ('si')
    final settings = container.read(settingsProvider);
    expect(settings.languageCode, 'si');
    expect(settings.hasSelectedLanguage, isTrue);
    expect(didContinue, isTrue);
  });
}

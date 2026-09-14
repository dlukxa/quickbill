import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/widgets/store_logo_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoreLogoWidget Tests', () {
    testWidgets('1. Renders fallback when logoUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoreLogoWidget(
              logoUrl: null,
              size: 40,
            ),
          ),
        ),
      );

      expect(find.byType(StoreLogoWidget), findsOneWidget);
      // Container sizing
      final containerFinder = find.byType(Container).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.constraints?.maxWidth, 40);
      expect(containerWidget.constraints?.maxHeight, 40);
    });

    testWidgets('2. Custom fallback widget is displayed when provided and logoUrl is empty', (tester) async {
      const customKey = Key('custom_fallback_test');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoreLogoWidget(
              logoUrl: '',
              size: 48,
              fallback: Icon(Icons.star, key: customKey),
            ),
          ),
        ),
      );

      expect(find.byKey(customKey), findsOneWidget);
    });

    testWidgets('3. Renders Image.network when logoUrl starts with http/https', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoreLogoWidget(
              logoUrl: 'https://example.com/shop_logo.png',
              size: 50,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<NetworkImage>());
      expect((imageWidget.image as NetworkImage).url, 'https://example.com/shop_logo.png');
    });

    testWidgets('4. Respects custom border, background color, and border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreLogoWidget(
              logoUrl: null,
              size: 64,
              borderRadius: 16,
              backgroundColor: Colors.amber,
              border: Border.all(color: Colors.red, width: 2),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDeco = containerWidget.decoration as BoxDecoration?;
      expect(boxDeco?.color, Colors.amber);
      expect(boxDeco?.borderRadius, BorderRadius.circular(16));
      expect(boxDeco?.border, isNotNull);
    });

    testWidgets('5. Renders Image.file when local file exists on disk', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('logo_test');
      final testFile = File('${tempDir.path}/test_logo.png')..writeAsStringSync('');

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StoreLogoWidget(
                logoUrl: testFile.path,
                size: 40,
              ),
            ),
          ),
          phase: EnginePhase.build,
        );

        expect(find.byType(Image), findsOneWidget);
        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.image, isA<FileImage>());
        expect((imageWidget.image as FileImage).file.path, testFile.path);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}

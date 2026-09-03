import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test - Verify simple widget rendering', (WidgetTester tester) async {
    // Build a simple component to verify widget testing works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('QuickBill'),
          ),
        ),
      ),
    );

    expect(find.text('QuickBill'), findsOneWidget);
    expect(find.text('Not present'), findsNothing);
  });
}

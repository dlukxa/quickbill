import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/screens/desktop/desktop_qr_link_screen.dart';
import 'package:quickbill/screens/desktop/desktop_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test DesktopQrLinkScreen build', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopQrLinkScreen(onLinked: (uid) {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Test DesktopWrapper build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopWrapper(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

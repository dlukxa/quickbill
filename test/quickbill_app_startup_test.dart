import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/main.dart';
import 'package:quickbill/services/startup_logger.dart';
import 'package:quickbill/widgets/developer_diagnostic_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QuickBillLoaderApp transitions past splash into QuickBillApp', (tester) async {
    StartupLogger.log('Test: Starting QuickBillLoaderApp test');

    await tester.pumpWidget(
      const RestartWidget(
        child: ProviderScope(
          child: QuickBillLoaderApp(),
        ),
      ),
    );

    // Initial frame (StartupLoadingScreen)
    await tester.pump();
    expect(find.byType(QuickBillLoaderApp), findsOneWidget);

    // Advance time for desktop fast path and timers
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsAtLeastNWidgets(1));
    expect(StartupLogger.inMemoryLogs.isNotEmpty, true);
  });

  testWidgets('DeveloperDiagnosticScreen renders exception, copy button, and restart button', (tester) async {
    const testException = 'FirebaseException: [core/no-app] No Firebase App [DEFAULT] has been created';
    final testDetails = FlutterErrorDetails(
      exception: testException,
      stack: StackTrace.current,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeveloperDiagnosticScreen(details: testDetails),
      ),
    );

    await tester.pump();

    expect(find.text('QuickBill POS — Technical Diagnostics'), findsOneWidget);
    expect(find.text(testException), findsOneWidget);
    expect(find.text('Restart QuickBill'), findsOneWidget);
    expect(find.text('Copy Diagnostics'), findsOneWidget);
  });

  test('StartupLogger logs to memory and resolves log path', () {
    StartupLogger.log('Testing diagnostic logging milestone');
    final logPath = StartupLogger.getLogFilePath();
    expect(logPath.isNotEmpty, true);
    expect(StartupLogger.inMemoryLogs.any((l) => l.contains('Testing diagnostic logging milestone')), true);
  });
}

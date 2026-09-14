import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/screens/desktop/desktop_pos_screen.dart';
import 'package:quickbill/screens/desktop/desktop_dashboard_view.dart';
import 'package:quickbill/screens/desktop/desktop_inventory_view.dart';
import 'package:quickbill/screens/desktop/desktop_sales_view.dart';
import 'package:quickbill/screens/desktop/desktop_customers_view.dart';
import 'package:quickbill/screens/desktop/desktop_suppliers_view.dart';
import 'package:quickbill/screens/desktop/desktop_expenses_view.dart';
import 'package:quickbill/screens/desktop/desktop_settings_view.dart';
import 'package:quickbill/screens/auth/profile_picker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize = const Size(1280, 800);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('Test ProfilePickerScreen build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfilePickerScreen(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopPosScreen build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopPosScreen(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopDashboardView build', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DesktopDashboardView(onNavigateTo: (_) {}),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopInventoryView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopInventoryView(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopSalesView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopSalesView(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopCustomersView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopCustomersView(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopSuppliersView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopSuppliersView(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopExpensesView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopExpensesView(),
        ),
      ),
    );
    await tester.pump();
  });

  testWidgets('Test DesktopSettingsView build', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DesktopSettingsView(),
        ),
      ),
    );
    await tester.pump();
  });
}

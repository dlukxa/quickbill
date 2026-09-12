import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/providers/desktop_nav_provider.dart';
import 'package:quickbill/screens/desktop/desktop_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Sidebar - Collapsible & Resizable Navigation Suite', () {
    testWidgets('1. Sized-up mode displays full labels, shortcuts, and default width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DesktopShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In expanded/sized-up mode:
      expect(find.text('POS Terminal'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Invoices & Sales'), findsOneWidget);
      expect(find.text('F1'), findsOneWidget);
      expect(find.text('F2'), findsWidgets);
      expect(find.text('F3'), findsOneWidget);
    });

    testWidgets('2. Collapsing to icon-only rail hides text labels and shows icons with tooltips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          desktopSidebarCollapsedProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In icon-only mode:
      // Text labels should NOT be rendered in the sidebar
      expect(find.text('POS Terminal'), findsNothing);
      expect(find.text('Invoices & Sales'), findsNothing);

      // But icons must exist
      expect(find.byIcon(Icons.point_of_sale_rounded), findsWidgets);
      expect(find.byIcon(Icons.analytics_rounded), findsWidgets);
      expect(find.byIcon(Icons.inventory_2_rounded), findsWidgets);

      // Tooltips should be present for accessibility and user guidance
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('3. Toggling sidebar state switches between icon-only and sized-up modes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially expanded
      expect(find.text('POS Terminal'), findsOneWidget);

      // Find and click the collapse button in the header
      final collapseBtn = find.byIcon(Icons.menu_open_rounded);
      expect(collapseBtn, findsWidgets);
      await tester.tap(collapseBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now collapsed to icons only
      expect(container.read(desktopSidebarCollapsedProvider), isTrue);
      expect(find.text('POS Terminal'), findsNothing);

      // Click the expand button to size up again
      final expandBtn = find.byIcon(Icons.menu_rounded);
      expect(expandBtn, findsWidgets);
      await tester.tap(expandBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now sized up again
      expect(container.read(desktopSidebarCollapsedProvider), isFalse);
      expect(find.text('POS Terminal'), findsOneWidget);
    });

    testWidgets('4. Navigation item selection switches active desktop view index', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(desktopNavIndexProvider), 0);

      // Tap Inventory (F3) in sidebar
      await tester.tap(find.text('Inventory'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(desktopNavIndexProvider), 2);
    });
  });
}

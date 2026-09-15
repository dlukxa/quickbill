import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/providers/product_provider.dart';
import 'package:quickbill/screens/desktop/desktop_inventory_view.dart';
import 'package:quickbill/widgets/inventory/bulk_stock_adjustment_dialog.dart';
import 'package:quickbill/widgets/inventory/excel_inventory_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleProducts = [
    Product(
      id: 1,
      name: 'Highland Fresh Milk 1L',
      nameSinhala: 'හයිලන්ඩ් නැවුම් කිරි 1L',
      baseBarcode: '4792011001',
      category: 'Dairy & Eggs',
      stock: 45.0,
      minStock: 10.0,
      costPrice: 420.0,
      price: 520.0,
      unit: 'bottle',
    ),
    Product(
      id: 2,
      name: 'Munchee Super Cream Cracker',
      nameSinhala: 'ක්‍රීම් ක්‍රැකර්',
      baseBarcode: '4792022002',
      category: 'Bakery & Snacks',
      stock: 4.0, // Low stock (<= 10)
      minStock: 10.0,
      costPrice: 200.0,
      price: 260.0,
      unit: 'pack',
    ),
    Product(
      id: 3,
      name: 'Ceylon Black Tea 400g',
      nameSinhala: 'තේ කොළ 400g',
      baseBarcode: '4792033003',
      category: 'Beverages',
      stock: 0.0, // Out of stock
      minStock: 15.0,
      costPrice: 650.0,
      price: 850.0,
      unit: 'pack',
    ),
  ];

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) async => sampleProducts),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize =
        const Size(1400, 900);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio =
        1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('ExcelInventoryTable Widget Tests', () {
    testWidgets('Renders all 11 columns and products data correctly',
        (tester) async {
      Set<int> selected = {};

      await tester.pumpWidget(
        buildTestApp(
          child: ExcelInventoryTable(
            products: sampleProducts,
            selectedProductIds: selected,
            onSelectionChanged: (set) => selected = set,
            sortColumn: 'name',
            sortAscending: true,
            onSort: (_, __) {},
          ),
        ),
      );
      await tester.pump();

      // Verify Column Headers
      expect(find.text('Sinhala Name'), findsOneWidget);
      expect(find.text('Min Stock'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);

      // Verify Product names rendered
      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Munchee Super Cream Cracker'), findsOneWidget);
      expect(find.text('Ceylon Black Tea 400g'), findsOneWidget);

      // Verify Sinhala names rendered
      expect(find.text('හයිලන්ඩ් නැවුම් කිරි 1L'), findsOneWidget);
      expect(find.text('ක්‍රීම් ක්‍රැකර්'), findsOneWidget);
      expect(find.text('තේ කොළ 400g'), findsOneWidget);

      // Verify Barcodes
      expect(find.text('4792011001'), findsOneWidget);
      expect(find.text('4792022002'), findsOneWidget);
      expect(find.text('4792033003'), findsOneWidget);
    });

    testWidgets('Row selection checkbox toggles correctly', (tester) async {
      Set<int> selected = {};

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildTestApp(
              child: ExcelInventoryTable(
                products: sampleProducts,
                selectedProductIds: selected,
                onSelectionChanged: (set) => setState(() => selected = set),
                sortColumn: 'name',
                sortAscending: true,
                onSort: (_, __) {},
              ),
            );
          },
        ),
      );
      await tester.pump();

      // Find checkboxes (1 in header + 3 in rows = 4)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4));

      // Tap first row checkbox (index 1)
      await tester.tap(checkboxes.at(1));
      await tester.pump();
      expect(selected.contains(1), isTrue);

      // Tap header checkbox (Select all)
      await tester.tap(checkboxes.at(0));
      await tester.pump();
      expect(selected.length, equals(3));
      expect(selected, containsAll([1, 2, 3]));
    });

    testWidgets('Tapping cell activates inline edit mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: ExcelInventoryTable(
            products: sampleProducts,
            selectedProductIds: const {},
            onSelectionChanged: (_) {},
            sortColumn: 'name',
            sortAscending: true,
            onSort: (_, __) {},
          ),
        ),
      );
      await tester.pump();

      // Tap on Highland Fresh Milk name cell
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pump();

      // TextField should now be visible in edit mode
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(find.text('Highland Fresh Milk 1L'), findsWidgets);

      // Press Escape key to cancel
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('BulkStockAdjustmentDialog Tests', () {
    testWidgets('Renders preview of selected items and mode options',
        (tester) async {
      final selectedItems = [sampleProducts[0], sampleProducts[1]];

      await tester.pumpWidget(
        buildTestApp(
          child: BulkStockAdjustmentDialog(
            selectedProducts: selectedItems,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bulk Stock Adjustment'), findsOneWidget);
      expect(find.text('Updating 2 selected products'), findsOneWidget);
      expect(find.text('Add Stock (+)'), findsOneWidget);
      expect(find.text('Deduct Stock (-)'), findsOneWidget);
      expect(find.text('Set Exact Stock (=)'), findsOneWidget);
      expect(find.text('Set Minimum Stock'), findsOneWidget);

      // Check item names in preview
      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Munchee Super Cream Cracker'), findsOneWidget);
    });

    testWidgets('Quantity changes reflect in preview calculation',
        (tester) async {
      final selectedItems = [sampleProducts[0]]; // Stock is 45.0

      await tester.pumpWidget(
        buildTestApp(
          child: BulkStockAdjustmentDialog(
            selectedProducts: selectedItems,
          ),
        ),
      );
      await tester.pump();

      // Default is Add (+10) -> New stock: 45 + 10 = 55
      expect(find.text('55 bottle'), findsOneWidget);

      // Switch to Deduct Stock mode
      await tester.tap(find.text('Deduct Stock (-)'));
      await tester.pump();
      // 45 - 10 = 35
      expect(find.text('35 bottle'), findsOneWidget);

      // Switch to Set Exact Stock mode
      await tester.tap(find.text('Set Exact Stock (=)'));
      await tester.pump();
      // Exact 10
      expect(find.text('10 bottle'), findsOneWidget);
    });
  });

  group('DesktopInventoryView Full Screen Tests', () {
    testWidgets('Renders KPI cards, search bar, filters and Excel table',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DesktopInventoryView(),
        ),
      );
      await tester.pump();

      // Verify Excel badge
      expect(find.text('Excel Edit Mode'), findsOneWidget);

      // Verify KPIs
      expect(find.text('Active SKUs'), findsOneWidget);
      expect(find.text('Below reorder threshold'), findsOneWidget);
      expect(find.text('Needs immediate restock'), findsOneWidget);
      expect(find.text('Inventory valuation at cost'), findsOneWidget);

      // Verify Search bar
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify Excel Table rendered inside
      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Munchee Super Cream Cracker'), findsOneWidget);
      expect(find.text('Ceylon Black Tea 400g'), findsOneWidget);

      // Filter by Low Stock segment
      await tester.tap(find.textContaining('Low Stock'));
      await tester.pump();

      // Only Munchee (stock 4, minStock 10) should be visible
      expect(find.text('Munchee Super Cream Cracker'), findsOneWidget);
      expect(find.text('Highland Fresh Milk 1L'), findsNothing);

      // Filter by Out of Stock segment
      await tester.tap(find.textContaining('Out of Stock'));
      await tester.pump();

      // Only Ceylon Tea (stock 0) should be visible
      expect(find.text('Ceylon Black Tea 400g'), findsOneWidget);
      expect(find.text('Munchee Super Cream Cracker'), findsNothing);
    });

    testWidgets('Search query filters by product name and Sinhala name',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DesktopInventoryView(),
        ),
      );
      await tester.pump();

      // Search for "Milk"
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Milk');
      await tester.pump();

      expect(find.text('Highland Fresh Milk 1L'), findsOneWidget);
      expect(find.text('Munchee Super Cream Cracker'), findsNothing);
      expect(find.text('Ceylon Black Tea 400g'), findsNothing);

      // Search for Sinhala "තේ"
      await tester.enterText(searchField, 'තේ');
      await tester.pump();

      expect(find.text('Ceylon Black Tea 400g'), findsOneWidget);
      expect(find.text('Highland Fresh Milk 1L'), findsNothing);
    });
  });

  group('Data Safety & Keyboard Navigation Tests', () {
    testWidgets('Tab key moves focus to next cell', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: ExcelInventoryTable(
            products: sampleProducts,
            selectedProductIds: const {},
            onSelectionChanged: (_) {},
            sortColumn: 'name',
            sortAscending: true,
            onSort: (_, __) {},
          ),
        ),
      );
      await tester.pump();

      // Tap on Highland Fresh Milk name cell
      await tester.tap(find.text('Highland Fresh Milk 1L'));
      await tester.pump();

      // Should be editing Name (col 1)
      expect(find.byType(TextField), findsOneWidget);

      // Send Tab key
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Should advance to Sinhala Name (col 2)
      final activeField = tester.widget<TextField>(find.byType(TextField));
      expect(activeField.controller?.text, equals('හයිලන්ඩ් නැවුම් කිරි 1L'));
    });
  });
}


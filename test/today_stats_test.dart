import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' show join;
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/providers/sale_provider.dart';
import 'package:quickbill/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'quickbill.db');
    await databaseFactory.deleteDatabase(path);

    dbService = DatabaseService.instance;
    await dbService.database;
  });

  group('Today Stats & Metrics Calculation Tests', () {
    test('getTodayStats returns accurate sales, profit, orders, and tickets with dual key names', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Insert a test product with cost price 100 and retail price 150
      final product = Product(
        branchId: 1,
        name: 'Test Coffee Packet',
        price: 150.0,
        costPrice: 100.0,
        stock: 50.0,
        category: 'Groceries',
      );
      final productId = await dbService.insertProduct(product);
      final insertedProduct = product.copyWith(id: productId);

      // 2. Create a sale of 2 items (Total 300, COGS 200, Profit 100)
      final cartItem = CartItem(
        product: insertedProduct,
        quantity: 2.0,
      );

      final saleActions = container.read(saleActionsProvider);
      final createdSale = await saleActions.createSale(
        cartItems: [cartItem],
        total: 300.0,
        discount: 0.0,
        paymentMethod: 'cash',
      );

      expect(createdSale.id, isNotNull);

      // 3. Query getTodayStats for branch 1
      final stats = await dbService.getTodayStats(1);

      // Verify snake_case keys (used by mobile HomeScreen & expense screens)
      expect(stats['total_sales'], equals(300.0));
      expect(stats['bill_count'], equals(1));
      expect(stats['total_profit'], equals(100.0));
      expect(stats['avg_bill'], equals(300.0));
      expect(stats['refunds'], equals(0.0));
      expect(stats['cogs'], equals(200.0));

      // Verify camelCase keys (used by DesktopDashboardView)
      expect(stats['totalSales'], equals(300.0));
      expect(stats['totalOrders'], equals(1));
      expect(stats['totalProfit'], equals(100.0));
      expect(stats['averageTicket'], equals(300.0));

      // 4. Verify consolidated branch (branchId = 0)
      final consolidatedStats = await dbService.getTodayStats(0);
      expect(consolidatedStats['totalSales'], equals(300.0));
      expect(consolidatedStats['totalOrders'], equals(1));
      expect(consolidatedStats['totalProfit'], equals(100.0));

      // 5. Verify getTopSellingProducts dual keys
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final topProducts = await dbService.getTopSellingProducts(5, start, end, 1);

      expect(topProducts.isNotEmpty, isTrue);
      final first = topProducts.first;
      expect(first['product_name'], equals('Test Coffee Packet'));
      expect(first['total_qty'], equals(2.0));
      expect(first['total_quantity'], equals(2.0));
      expect(first['total_sales'], equals(300.0));
      expect(first['totalSales'], equals(300.0));
    });
  });
}

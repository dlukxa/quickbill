import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:quickbill/services/database_service.dart';
import 'package:quickbill/services/return_service.dart';
import 'package:quickbill/models/sales_return.dart';
import 'package:quickbill/models/sales_return_item.dart';

void main() {
  late DatabaseService dbService;
  late ReturnService returnService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'quickbill.db');
    await databaseFactory.deleteDatabase(path);
    
    // We need to reset the singleton's internal db reference if it persists, 
    // but DatabaseService.instance is just the instance. The _database Future might be cached via `_database` field?
    // DatabaseService has `static Database? _database;`
    // We cannot access private field.
    // However, if we deleted the file, and `_database` is still open, it might cause issues.
    // Ideally we should restart the isolate or class state, but we can't easily.
    // If `_database` is already initialized in a previous test (if we had specific order), it stays open.
    // But since we are running a single test file, initially it is null.
    // setUp runs before EACH test.
    // If we have multiple tests, second test will fail if `_database` is not null but file is deleted.
    // BUT we only have one test now.
    
    dbService = DatabaseService.instance;
    await dbService.database; // This will call initDatabase
  });

  test('Process Return Restocks Item correctly', () async {
    // 1. Setup Data
    final db = await dbService.database;
    
    // Create Product
    final productId = await db.insert('products', {
      'name': 'Test Product',
      'price': 100.0,
      'stock': 10.0,
      'category': 'General',
      'base_barcode': 'SKU123',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    
    // Create Sale
    final saleId = await db.insert('sales', {
      'bill_number': 'INV-001',
      'total': 200.0,
      'items_count': 1,
      'payment_method': 'cash',
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Create Sale Item
    await db.insert('sale_items', {
      'sale_id': saleId,
      'product_id': productId,
      'product_name': 'Test Product',
      'quantity': 2.0,
      'unit_price': 100.0,
      'total': 200.0,
    });
    
    // Simulate stock reduction from sale (10 -> 8)
    await db.update('products', {'stock': 8.0}, where: 'id = ?', whereArgs: [productId]);
    
    final p1 = await dbService.getProductById(productId);
    expect(p1!.stock, 8.0);
    
    // 2. Process Return
    returnService = ReturnService(dbService: dbService);
    
    final returnData = SalesReturn(
      saleId: saleId,
      branchId: 1,
      returnDate: DateTime.now(),
      refundAmount: 100.0,
      refundType: 'cash',
      reason: 'Defective',
      employeeId: 1,
    );
    
    final itemToReturn = SalesReturnItem(
        returnId: 0, // placeholder
        productId: productId,
        quantity: 1.0,
        refundAmount: 100.0,
        condition: 'restockable', // Should increase stock
    );
    
    await returnService.processReturn(
      returnData: returnData,
      items: [itemToReturn],
    );
    
    // 3. Verify
    // Stock should be 8 + 1 = 9.
    final p2 = await dbService.getProductById(productId);
    expect(p2!.stock, 9.0);
    
    // Returns table should have entry
    final returns = await returnService.getReturnsForSale(saleId, 1);
    expect(returns.length, 1);
    expect(returns.first.refundAmount, 100.0);
  });
}

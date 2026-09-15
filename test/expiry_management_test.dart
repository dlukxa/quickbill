import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' show join;
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/product_batch.dart';
import 'package:quickbill/models/stock_expiry_item.dart';
import 'package:quickbill/providers/cart_provider.dart';
import 'package:quickbill/providers/expiry_provider.dart';
import 'package:quickbill/providers/sale_provider.dart';
import 'package:quickbill/providers/branch_provider.dart';
import 'package:quickbill/services/database_service.dart';
import 'package:quickbill/services/pos_barcode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestWidgetRef implements WidgetRef {
  final ProviderContainer _container;
  _TestWidgetRef(this._container);

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  bool exists(ProviderBase<Object?> provider) => _container.exists(provider);

  @override
  void invalidate(ProviderOrFamily provider) => _container.invalidate(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    _container.listen(provider, listener, onError: onError);
  }

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) {
    return _container.listen(provider, listener, onError: onError, fireImmediately: fireImmediately);
  }

  @override
  T refresh<T>(Refreshable<T> provider) => _container.refresh(provider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dbService = DatabaseService.instance;
    await dbService.close();

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'quickbill.db');
    await databaseFactory.deleteDatabase(path);

    await dbService.database;
  });

  tearDown(() async {
    await dbService.close();
  });

  group('1. StockExpiryItem & Domain Model Tests', () {
    test('StockExpiryItem computes daysUntilExpiry, isExpired, and isExpiringSoon accurately', () {
      final now = DateTime.now();

      // Expired 5 days ago
      final expiredItem = StockExpiryItem(
        productId: 1,
        productName: 'Fresh Whole Milk 1L',
        barcode: 'MILK001',
        stock: 12.0,
        price: 350.0,
        expiryDate: now.subtract(const Duration(days: 5)),
      );
      expect(expiredItem.isExpired, isTrue);
      expect(expiredItem.daysUntilExpiry, lessThan(0));
      expect(expiredItem.getStatus(30), ExpiryStatus.expired);
      expect(expiredItem.statusLabel(30), contains('Expired 5 days ago'));

      // Expiring in 10 days
      final expiringItem = StockExpiryItem(
        productId: 2,
        productName: 'Cheddar Cheese 200g',
        barcode: 'CHS002',
        batchNumber: 'BATCH-2026-A',
        stock: 8.0,
        price: 520.0,
        expiryDate: now.add(const Duration(days: 10)),
        isBatchTracked: true,
      );
      expect(expiringItem.isExpired, isFalse);
      expect(expiringItem.isExpiringSoon(30), isTrue); // Within 30 days
      expect(expiringItem.isExpiringSoon(7), isFalse);  // Not within 7 days
      expect(expiringItem.getStatus(30), ExpiryStatus.expiringSoon);
      expect(expiringItem.getStatus(7), ExpiryStatus.valid);
      expect(expiringItem.statusLabel(30), contains('Expires in 10 days'));

      // Valid - expires in 120 days
      final validItem = StockExpiryItem(
        productId: 3,
        productName: 'Dry Basmati Rice 5kg',
        barcode: 'RICE003',
        stock: 50.0,
        price: 1200.0,
        expiryDate: now.add(const Duration(days: 120)),
      );
      expect(validItem.isExpired, isFalse);
      expect(validItem.isExpiringSoon(30), isFalse);
      expect(validItem.isExpiringSoon(90), isFalse);
      expect(validItem.getStatus(30), ExpiryStatus.valid);
      expect(validItem.statusLabel(30), contains('Valid'));
    });

    test('Product model serializes and deserializes expiryDate correctly', () {
      final expiry = DateTime(2026, 12, 31);
      final product = Product(
        branchId: 1,
        name: 'Yogurt Cup 100g',
        price: 80.0,
        costPrice: 60.0,
        stock: 25.0,
        expiryDate: expiry,
      );

      final map = product.toMap();
      expect(map['expiry_date'], expiry.toIso8601String());

      final fromMapProduct = Product.fromMap(map);
      expect(fromMapProduct.expiryDate, isNotNull);
      expect(fromMapProduct.expiryDate!.year, 2026);
      expect(fromMapProduct.expiryDate!.month, 12);
      expect(fromMapProduct.expiryDate!.day, 31);

      // copyWith
      final updated = product.copyWith(expiryDate: DateTime(2027, 1, 15));
      expect(updated.expiryDate!.year, 2027);
    });

    test('CartItem isExpired getter reflects product and batch expiry status', () {
      final now = DateTime.now();

      final expiredProduct = Product(
        branchId: 1,
        name: 'Expired Bread',
        price: 150.0,
        stock: 5.0,
        expiryDate: now.subtract(const Duration(days: 2)),
      );
      final cartItem1 = CartItem(product: expiredProduct, quantity: 1.0);
      expect(cartItem1.isExpired, isTrue);

      final validProduct = Product(
        branchId: 1,
        name: 'Fresh Bread',
        price: 150.0,
        stock: 10.0,
        expiryDate: now.add(const Duration(days: 3)),
      );
      final cartItem2 = CartItem(product: validProduct, quantity: 1.0);
      expect(cartItem2.isExpired, isFalse);

      // Expired batch override
      final expiredBatch = ProductBatch(
        id: 10,
        productId: validProduct.id ?? 1,
        batchNumber: 'B-EXP-01',
        barcode: 'BATCH-BARCODE-EXP',
        stock: 5.0,
        initialStock: 5.0,
        expiryDate: now.subtract(const Duration(days: 1)),
      );
      final cartItemWithExpiredBatch = CartItem(
        product: validProduct.copyWith(batches: [expiredBatch]),
        batchId: expiredBatch.id,
        quantity: 1.0,
      );
      expect(cartItemWithExpiredBatch.isExpired, isTrue);
    });
  });

  group('2. SQLite Schema & DatabaseService Expiry Queries', () {
    test('DB v30 products table contains expiry_date column', () async {
      final db = await dbService.database;
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final colNames = columns.map((c) => c['name'] as String).toList();

      expect(colNames.contains('expiry_date'), isTrue,
          reason: 'products table must include expiry_date column in v30');
    });

    test('getAllStockExpiryItems returns combined batch and non-batch products with expiry', () async {
      final now = DateTime.now();

      // 1. Insert product with direct expiry date (no batches)
      final p1 = Product(
        branchId: 1,
        name: 'Packaged Fresh Juice 1L',
        baseBarcode: 'JUICE001',
        price: 250.0,
        costPrice: 180.0,
        stock: 15.0,
        category: 'Beverages',
        expiryDate: now.subtract(const Duration(days: 3)), // Expired
      );
      await dbService.insertProduct(p1);

      // 2. Insert product with 2 batches
      final p2 = Product(
        branchId: 1,
        name: 'Greek Yogurt 500g',
        baseBarcode: 'YOGURT002',
        price: 450.0,
        costPrice: 320.0,
        stock: 20.0,
        category: 'Dairy',
        trackBatches: true,
      );
      final p2Id = await dbService.insertProduct(p2);

      // Batch A: Expiring soon (5 days)
      await dbService.addProductBatch(ProductBatch(
        productId: p2Id,
        batchNumber: 'BATCH-YOG-01',
        barcode: 'YOG-B1',
        stock: 8.0,
        initialStock: 10.0,
        expiryDate: now.add(const Duration(days: 5)),
      ));

      // Batch B: Valid (60 days)
      await dbService.addProductBatch(ProductBatch(
        productId: p2Id,
        batchNumber: 'BATCH-YOG-02',
        barcode: 'YOG-B2',
        stock: 12.0,
        initialStock: 15.0,
        expiryDate: now.add(const Duration(days: 60)),
      ));

      // 3. Query all stock expiry items
      final allExpiryItems = await dbService.getAllStockExpiryItems(branchId: 1);

      expect(allExpiryItems.length, 3);

      final expiredItems = allExpiryItems.where((i) => i.isExpired).toList();
      expect(expiredItems.length, 1);
      expect(expiredItems.first.productName, 'Packaged Fresh Juice 1L');
      expect(expiredItems.first.batchId, isNull);

      final batchItems = allExpiryItems.where((i) => i.batchId != null).toList();
      expect(batchItems.length, 2);
      expect(batchItems.any((b) => b.batchNumber == 'BATCH-YOG-01'), isTrue);
      expect(batchItems.any((b) => b.batchNumber == 'BATCH-YOG-02'), isTrue);
    });
  });

  group('3. Billing Safety & FEFO Non-Expired Depletion', () {
    test('createSale FEFO strictly ignores expired batches and only depletes valid stock', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();

      // Product with 2 batches: one expired yesterday, one valid for 45 days
      final product = Product(
        branchId: 1,
        name: 'Fresh Farm Eggs 10pk',
        price: 350.0,
        costPrice: 280.0,
        stock: 25.0,
        category: 'Dairy',
        trackBatches: true,
      );
      final productId = await dbService.insertProduct(product);
      final insertedProduct = product.copyWith(id: productId);

      // Expired Batch: 10 units expired 2 days ago
      final expiredBatchId = await dbService.addProductBatch(ProductBatch(
        productId: productId,
        batchNumber: 'EGGS-EXP',
        barcode: 'EGGS-EXP-BARCODE',
        stock: 10.0,
        initialStock: 10.0,
        expiryDate: now.subtract(const Duration(days: 2)),
      ));

      // Valid Batch: 15 units expiring in 45 days
      final validBatchId = await dbService.addProductBatch(ProductBatch(
        productId: productId,
        batchNumber: 'EGGS-VAL',
        barcode: 'EGGS-VAL-BARCODE',
        stock: 15.0,
        initialStock: 15.0,
        expiryDate: now.add(const Duration(days: 45)),
      ));

      // Attempt sale of 5 units
      final saleActions = container.read(saleActionsProvider);
      final sale = await saleActions.createSale(
        cartItems: [
          CartItem(product: insertedProduct, quantity: 5.0),
        ],
        total: 1750.0,
        discount: 0.0,
        paymentMethod: 'cash',
      );

      expect(sale.id, isNotNull);

      // Check remaining stock in batches
      final batchesAfterSale = await dbService.getProductBatches(productId);
      final expiredBatchAfter = batchesAfterSale.firstWhere((b) => b.id == expiredBatchId);
      final validBatchAfter = batchesAfterSale.firstWhere((b) => b.id == validBatchId);

      // The expired batch MUST remain untouched (10.0)
      expect(expiredBatchAfter.stock, 10.0,
          reason: 'Expired batch must NOT be depleted by FEFO during checkout');

      // The valid batch should have 15.0 - 5.0 = 10.0 remaining
      expect(validBatchAfter.stock, 10.0,
          reason: 'Valid batch must be depleted first');
    });

    test('PosBarcodeService rejects expired batch scans and prevents adding to cart', () async {
      final now = DateTime.now();

      final product = Product(
        branchId: 1,
        name: 'Pasteurized Cream 250ml',
        baseBarcode: 'CREAM-PROD',
        price: 200.0,
        stock: 10.0,
        trackBatches: true,
      );
      final pId = await dbService.insertProduct(product);

      // Expired batch with dedicated barcode
      await dbService.addProductBatch(ProductBatch(
        productId: pId,
        batchNumber: 'CREAM-EXPBATCH',
        barcode: 'SCAN-EXPIRED-BARCODE',
        stock: 5.0,
        initialStock: 5.0,
        expiryDate: now.subtract(const Duration(days: 1)),
      ));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: 'SCAN-EXPIRED-BARCODE',
        ref: _TestWidgetRef(container),
        playSound: false,
      );

      expect(result.isSuccess, isFalse,
          reason: 'Scanning an expired batch barcode must not succeed');
      expect(result.message.toLowerCase(), contains('expired'));

      // Cart should remain empty
      final cart = container.read(cartProvider);
      expect(cart.isEmpty, isTrue,
          reason: 'Expired item must not be added to cart on barcode scan');
    });
  });

  group('4. Stock Write-Off & Disposal Actions', () {
    test('writeOffBatchStock reduces batch and product stock without deleting product record', () async {
      final now = DateTime.now();

      final product = Product(
        branchId: 1,
        name: 'Sliced Sandwich Bread',
        price: 180.0,
        costPrice: 120.0,
        stock: 20.0,
        trackBatches: true,
      );
      final pId = await dbService.insertProduct(product);

      final batchId = await dbService.addProductBatch(ProductBatch(
        productId: pId,
        batchNumber: 'BREAD-001',
        barcode: 'BREAD-BARCODE-001',
        stock: 10.0,
        initialStock: 10.0,
        expiryDate: now.subtract(const Duration(days: 1)),
      ));

      // Write off 6 expired units
      await dbService.writeOffBatchStock(
        productId: pId,
        batchId: batchId,
        branchId: 1,
        quantity: 6.0,
        reason: 'expired',
        notes: 'Disposed due to mold / past expiry date',
      );

      // Verify batch stock
      final batches = await dbService.getProductBatches(pId);
      final batch = batches.firstWhere((b) => b.id == batchId);
      expect(batch.stock, 4.0);

      // Verify product aggregate stock
      final updatedProduct = await dbService.getProductById(pId);
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stock, 14.0); // 20 - 6 = 14
      expect(updatedProduct.deleted, isNot(true),
          reason: 'Product record must never be deleted when writing off stock');

      // Verify stock history entry exists
      final db = await dbService.database;
      final history = await db.query(
        'stock_history',
        where: 'product_id = ?',
        whereArgs: [pId],
      );
      expect(history.isNotEmpty, isTrue);
      expect(history.any((h) => (h['type'] as String).contains('wastage_expired')), isTrue);
    });
  });

  group('5. Riverpod Expiry State & Thresholds Tests', () {
    test('expirySummaryProvider accurately counts expired and expiring items based on active threshold', () async {
      final now = DateTime.now();

      // Insert:
      // 1. Expired product (5 qty)
      await dbService.insertProduct(Product(
        branchId: 1,
        name: 'Sour Cream',
        price: 120.0,
        stock: 5.0,
        expiryDate: now.subtract(const Duration(days: 4)),
      ));

      // 2. Product expiring in 12 days (10 qty)
      await dbService.insertProduct(Product(
        branchId: 1,
        name: 'Butter 200g',
        price: 300.0,
        stock: 10.0,
        expiryDate: now.add(const Duration(days: 12)),
      ));

      // 3. Product expiring in 40 days (25 qty)
      await dbService.insertProduct(Product(
        branchId: 1,
        name: 'Canned Beans 400g',
        price: 150.0,
        stock: 25.0,
        expiryDate: now.add(const Duration(days: 40)),
      ));

      final container = ProviderContainer(
        overrides: [
          currentBranchIdProvider.overrideWithValue(1),
        ],
      );
      addTearDown(container.dispose);

      // Wait for data to load
      final items = await container.read(stockExpiryItemsProvider.future);
      expect(items.length, 3);

      // Default threshold is 30 days
      final summaryAt30 = container.read(expirySummaryProvider);
      expect(summaryAt30.totalExpiredProducts, 1);
      expect(summaryAt30.totalExpiredStockQty, 5.0);
      expect(summaryAt30.expiringSoonProducts, 1); // Only Butter (12 days <= 30)
      expect(summaryAt30.expiringSoonStockQty, 10.0);
      expect(summaryAt30.validProducts, 1); // Canned Beans (40 days > 30)

      // Change threshold to 60 days
      container.read(expiryAlertThresholdProvider.notifier).state = 60;
      final summaryAt60 = container.read(expirySummaryProvider);
      expect(summaryAt60.totalExpiredProducts, 1);
      expect(summaryAt60.expiringSoonProducts, 2); // Both Butter (12) and Beans (40) are <= 60
      expect(summaryAt60.expiringSoonStockQty, 35.0);
      expect(summaryAt60.validProducts, 0);

      // Change threshold to 7 days
      container.read(expiryAlertThresholdProvider.notifier).state = 7;
      final summaryAt7 = container.read(expirySummaryProvider);
      expect(summaryAt7.totalExpiredProducts, 1);
      expect(summaryAt7.expiringSoonProducts, 0); // Neither 12 nor 40 days <= 7
      expect(summaryAt7.validProducts, 2);
    });

    test('filteredExpiryItemsProvider filters by tab and search query', () async {
      final now = DateTime.now();

      final pId1 = await dbService.insertProduct(Product(
        branchId: 1,
        name: 'Chocolate Milk 180ml',
        baseBarcode: 'CHOC001',
        price: 90.0,
        stock: 20.0,
        category: 'Beverages',
        expiryDate: now.subtract(const Duration(days: 1)), // Expired
      ));

      final pId2 = await dbService.insertProduct(Product(
        branchId: 1,
        name: 'Strawberry Milk 180ml',
        baseBarcode: 'STRAW002',
        price: 90.0,
        stock: 15.0,
        category: 'Beverages',
        expiryDate: now.add(const Duration(days: 8)), // Expiring soon
      ));

      final container = ProviderContainer(
        overrides: [
          currentBranchIdProvider.overrideWithValue(1),
        ],
      );
      addTearDown(container.dispose);

      await container.read(stockExpiryItemsProvider.future);

      // Filter: Expired tab
      container.read(expiryFilterProvider.notifier).setTab(ExpiryTab.expired);
      var filtered = container.read(filteredExpiryItemsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.productId, pId1);

      // Filter: Expiring Soon tab
      container.read(expiryFilterProvider.notifier).setTab(ExpiryTab.expiringSoon);
      filtered = container.read(filteredExpiryItemsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.productId, pId2);

      // Search Query
      container.read(expiryFilterProvider.notifier).setTab(ExpiryTab.all);
      container.read(expiryFilterProvider.notifier).setSearchQuery('Straw');
      filtered = container.read(filteredExpiryItemsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.productName, 'Strawberry Milk 180ml');
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_batch.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'product_provider.dart';

// Provider for database service
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// Provider to get all batches for a specific product
final productBatchesProvider = FutureProvider.family<List<ProductBatch>, int>((ref, productId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getProductBatches(productId);
});

// Provider to get only available batches (stock > 0) for a product
final availableBatchesProvider = FutureProvider.family<List<ProductBatch>, int>((ref, productId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAvailableBatches(productId);
});

// Provider to get expiring batches
final expiringBatchesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, daysAhead) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getExpiringBatches(daysAhead, branchId);
});

// Provider to get expired batches
final expiredBatchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getExpiredBatches(branchId);
});

// Provider for batch actions
final batchActionsProvider = Provider((ref) => BatchActions(ref));

class BatchActions {
  final Ref _ref;

  BatchActions(this._ref);

  Future<int> addBatch(ProductBatch batch) async {
    final db = _ref.read(databaseServiceProvider);
    final id = await db.addProductBatch(batch);
    
    // Invalidate providers to refresh data
    _ref.invalidate(productBatchesProvider(batch.productId));
    _ref.invalidate(availableBatchesProvider(batch.productId));
    _ref.invalidate(productsProvider);
    _ref.invalidate(lowStockProductsProvider);
    _ref.invalidate(productByIdProvider(batch.productId));
    
    return id;
  }
  
  Future<ProductBatch?> getBatchByBarcode(String barcode) async {
    final db = _ref.read(databaseServiceProvider);
    return await db.getBatchByBarcode(barcode);
  }
  
  Future<void> updateBatchStock(int batchId, int newStock, String type, {int? referenceId, String? notes, required int productId}) async {
    final db = _ref.read(databaseServiceProvider);
    await db.updateBatchStock(batchId, newStock, type, referenceId: referenceId, notes: notes);
    
    // Invalidate providers
    _ref.invalidate(productBatchesProvider(productId));
    _ref.invalidate(availableBatchesProvider(productId));
    _ref.invalidate(productsProvider);
    _ref.invalidate(lowStockProductsProvider);
    _ref.invalidate(productByIdProvider(productId));
  }

  Future<void> updateBatch(ProductBatch batch) async {
    final db = _ref.read(databaseServiceProvider);
    await db.updateProductBatch(batch);
    
    // Invalidate providers
    _ref.invalidate(productBatchesProvider(batch.productId));
    _ref.invalidate(availableBatchesProvider(batch.productId));
    _ref.invalidate(productsProvider);
    _ref.invalidate(lowStockProductsProvider);
    _ref.invalidate(productByIdProvider(batch.productId));
  }

  Future<void> deleteBatch(int batchId, int productId) async {
    final db = _ref.read(databaseServiceProvider);
    await db.deleteProductBatch(batchId);
    
    // Invalidate providers
    _ref.invalidate(productBatchesProvider(productId));
    _ref.invalidate(availableBatchesProvider(productId));
    _ref.invalidate(productsProvider);
    _ref.invalidate(lowStockProductsProvider);
    _ref.invalidate(productByIdProvider(productId));
  }
}

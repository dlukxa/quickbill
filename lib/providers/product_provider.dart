import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../services/database_service.dart';
import 'preference_provider.dart';
import 'employee_provider.dart';
import 'branch_provider.dart';

// Database service provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// All products provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getAllProducts(branchId);
});

// Search products provider
final searchProductsProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  if (query.isEmpty) {
    return await db.getAllProducts(branchId);
  }
  return await db.searchProducts(query, branchId);
});

// Low stock products provider
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final settings = ref.watch(settingsProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getLowStockProducts(branchId, settings.lowStockThreshold);
});

// Archived (soft-deleted) products provider
final archivedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getArchivedProducts(branchId);
});

// Product by ID provider
final productByIdProvider = FutureProvider.family<Product?, int>((ref, id) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getProductWithBatches(id); // Use new method to get batches too
});

// Product analytics provider
final productAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, productId) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getProductAnalytics(productId, branchId);
});

// Product by barcode provider (Legacy support + batch awareness)
final productByBarcodeProvider = FutureProvider.family<Product?, String>((ref, barcode) async {
  final db = ref.watch(databaseServiceProvider);
  final result = await db.findByBarcode(barcode);
  if (result == null) return null;
  return result['product'] as Product;
});

// Product AND Batch by barcode provider
final productAndBatchByBarcodeProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, barcode) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.findByBarcode(barcode);
});

// Product actions
class ProductActions {
  final Ref ref;

  ProductActions(this.ref);

  Future<int> addProduct(Product product, {ProductBatch? initialBatch}) async {
    final db = ref.read(databaseServiceProvider);
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    
    // Ensure product has the correct branchId
    final productWithBranch = product.copyWith(branchId: branchId);
    
    // Use enhanced functionality if initial batch provided
    if (initialBatch != null) {
      final id = await db.insertProduct(productWithBranch);
      
      final batch = initialBatch.copyWith(
        productId: id,
        branchId: branchId,
      );
      await db.addProductBatch(batch);
      
      ref.invalidate(productsProvider);
      return id;
    } else {
      final id = await db.insertProduct(productWithBranch);
      ref.invalidate(productsProvider);
      return id;
    }
  }

  Future<void> updateProduct(Product product) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateProduct(product);
    ref.invalidate(productsProvider);
    ref.invalidate(productByIdProvider(product.id!));
  }

  Future<void> updateStock(int productId, double newStock) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateProductStock(productId, newStock);
    ref.invalidate(productsProvider);
    ref.invalidate(productByIdProvider(productId));
    ref.invalidate(lowStockProductsProvider);
  }

  Future<void> adjustStock({
    required int productId,
    required double quantityChange,
    required String notes,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final employeeId = ref.read(currentEmployeeProvider).value?.id;
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    await db.adjustStock(
      productId: productId,
      branchId: branchId,
      quantityChange: quantityChange,
      notes: notes,
      employeeId: employeeId,
    );
    ref.invalidate(productsProvider);
    ref.invalidate(productByIdProvider(productId));
    ref.invalidate(lowStockProductsProvider);
  }

  Future<void> deleteProduct(int productId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteProduct(productId);
    ref.invalidate(productsProvider);
    ref.invalidate(archivedProductsProvider);
  }

  Future<void> restoreProduct(int productId) async {
    final db = ref.read(databaseServiceProvider);
    await db.restoreProduct(productId);
    ref.invalidate(productsProvider);
    ref.invalidate(archivedProductsProvider);
    ref.invalidate(lowStockProductsProvider);
  }
}

// Product actions provider
final productActionsProvider = Provider((ref) => ProductActions(ref));

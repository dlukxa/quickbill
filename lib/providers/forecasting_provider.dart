import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'product_provider.dart';
import 'branch_provider.dart';

class StockForecast {
  final int productId;
  final double dailyVelocity;
  final double daysRemaining;
  final double recommendedReorder;

  StockForecast({
    required this.productId,
    required this.dailyVelocity,
    required this.daysRemaining,
    required this.recommendedReorder,
  });

  bool get isCritical => daysRemaining < 3;
}

/// Provider for all products' sales velocities in a single batch query
final allProductsVelocityProvider = FutureProvider<Map<int, double>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 0;
  return await db.getAllProductsSalesVelocity(branchId);
});

/// Provider for a specific product's stock forecast (synchronous in-memory lookup)
final productForecastProvider = Provider.family<StockForecast?, int>((ref, productId) {
  final productsAsync = ref.watch(productsProvider);
  final velocitiesAsync = ref.watch(allProductsVelocityProvider);

  final products = productsAsync.value;
  final velocities = velocitiesAsync.value;
  
  if (products == null || velocities == null) return null;

  final productIndex = products.indexWhere((p) => p.id == productId);
  if (productIndex == -1) return null;
  final product = products[productIndex];

  final double velocity = velocities[productId] ?? 0.0;
  
  if (velocity <= 0) {
    return StockForecast(
      productId: productId,
      dailyVelocity: 0,
      daysRemaining: double.infinity,
      recommendedReorder: 0,
    );
  }

  // Use calculatedStock which accounts for batch totals if batch-tracked
  final double currentStock = product.calculatedStock;
  final double daysRemaining = currentStock / velocity;
  
  // Aim for a 14-day safety buffer
  final double recommendedReorder = (velocity * 14) - currentStock;

  return StockForecast(
    productId: productId,
    dailyVelocity: velocity,
    daysRemaining: daysRemaining,
    recommendedReorder: recommendedReorder > 0 ? recommendedReorder : 0,
  );
});

/// Provider for all critical forecasts (stockout in < 3 days)
final criticalForecastsProvider = FutureProvider<List<StockForecast>>((ref) async {
  // Await the futures of dependencies to ensure values are resolved
  await ref.watch(productsProvider.future);
  await ref.watch(allProductsVelocityProvider.future);

  final products = ref.read(productsProvider).value ?? [];
  final List<StockForecast> criticals = [];

  for (final product in products) {
    final forecast = ref.watch(productForecastProvider(product.id!));
    if (forecast != null && forecast.isCritical) {
      criticals.add(forecast);
    }
  }

  // Sort by urgency
  criticals.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  return criticals;
});

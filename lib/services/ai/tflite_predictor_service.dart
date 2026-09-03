import 'package:flutter/foundation.dart';
import '../../services/database_service.dart';

class TFLitePredictorService {
  final DatabaseService _dbService;

  static final TFLitePredictorService _instance = TFLitePredictorService._internal();
  static TFLitePredictorService get instance => _instance;
  
  TFLitePredictorService._internal() : _dbService = DatabaseService.instance;

  Future<List<String>> generateBackgroundInsights(int branchId) async {
    // In a real scenario, we load Interpreter.fromAsset('model.tflite')
    // Here we use a heuristic mock to represent the fast offline "TFLite model" analyzing data.
    
    try {
      final List<String> insights = [];
      
      // Feature 1: Expiry risk predictions (mock logic based on low stock / stock level)
      final lowStock = await _dbService.getLowStockProducts(branchId);
      if (lowStock.isNotEmpty) {
        insights.add("Critical: ${lowStock.length} items are running below minimum stock. Consider reordering ${lowStock.first.name} immediately.");
      }
      
      // Feature 2: Sales velocity prediction based on top selling items
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final topSelling = await _dbService.getTopSellingProducts(3, thirtyDaysAgo, DateTime.now(), branchId);
      if (topSelling.isNotEmpty) {
        final topItem = topSelling.first;
        insights.add("Prediction: Based on recent velocity, '${topItem['product_name']}' might sell out by this weekend. Consider a batch order.");
      }
      
      // Feature 3: General trend anomaly
      insights.add("Insight: Customer footfall generally peaks between 4 PM and 6 PM. Consider running flash discounts then.");
      
      return insights;
    } catch (e) {
      debugPrint("Error generating background insights: $e");
      return ["No recent insights available."];
    }
  }
}

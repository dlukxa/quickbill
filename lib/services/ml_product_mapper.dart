import '../../models/product.dart';

class MLProductMapper {
  /// Maps generic AI labels (simulation) to actual shop products.
  static final Map<String, List<String>> _simulationMappings = {
    'bottle': ['coca_cola', 'pepsi', 'water_bottle', 'sprite'],
    'fruit': ['apple', 'banana', 'orange', 'mango'],
    'vegetable': ['carrot', 'potato', 'onion', 'tomato'],
    'snack': ['chips', 'biscuits', 'chocolate'],
    'drink': ['coke', 'juice', 'milk', 'coffee'],
  };

  /// Simple mapping between AI labels and product IDs or Names.
  static String? mapLabelToProductId(String label, List<Product> products, {bool isSimulation = false}) {
    final normalizedLabel = label.toLowerCase().trim().replaceAll(' ', '_');
    
    // 1. Simulation Mapping
    if (isSimulation) {
      // Check if generic label exists in simulation map
      final mappedKeywords = _simulationMappings[normalizedLabel];
      if (mappedKeywords != null) {
        // Try to find a product that matches any of the keywords
        for (final product in products) {
          final prodName = product.name.toLowerCase().replaceAll(' ', '_');
          for (final keyword in mappedKeywords) {
            if (prodName.contains(keyword)) return product.id.toString();
          }
        }
      }
    }

    // 2. Direct/Fuzzy Match (for custom model or fallback)
    for (final product in products) {
      final normalizedProductName = product.name.toLowerCase().replaceAll(' ', '_');
      
      // Strict match
      if (normalizedProductName == normalizedLabel) return product.id.toString();
      
      // Contains match (at least 3 chars to avoid false positives like "a")
      if (normalizedLabel.length >= 3 && 
          (normalizedProductName.contains(normalizedLabel) || 
           normalizedLabel.contains(normalizedProductName))) {
        return product.id.toString();
      }
    }
    return null;
  }

  static Product? findMappedProduct(String label, List<Product> products, {bool isSimulation = false}) {
    final productId = mapLabelToProductId(label, products, isSimulation: isSimulation);
    if (productId == null) return null;
    
    try {
      return products.firstWhere((p) => p.id.toString() == productId);
    } catch (e) {
      return null;
    }
  }
}

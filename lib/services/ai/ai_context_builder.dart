import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product.dart';
import '../../services/database_service.dart';
import 'ai_intent_router.dart';

class AIContextBuilder {
  final DatabaseService _dbService;
  
  AIContextBuilder({DatabaseService? dbService}) 
      : _dbService = dbService ?? DatabaseService.instance;

  Future<String> buildContext(AIIntent intent, int branchId, String query) async {
    try {
      switch (intent) {
        case AIIntent.companyProfile:
          return await _buildCompanyContext(branchId);
        case AIIntent.salesReport:
          return await _buildSalesContext(branchId, query.toLowerCase());
        case AIIntent.inventoryStatus:
        case AIIntent.lowStockAlerts:
          return await _buildInventoryContext(branchId, intent == AIIntent.lowStockAlerts);
        case AIIntent.generalChat:
          return "I am the QuickBill Assistant for your shop. I can tell you about your sales, stock levels, or shop information. What can I do for you?";
      }
    } catch (e) {
      return "I'm having trouble fetching that data right now. Please try again.";
    }
  }

  Future<String> _buildCompanyContext(int branchId) async {
    // Read from SharedPreferences — the authoritative source for shop identity
    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString('shop_name') ?? 'This shop';
    final shopAddress = prefs.getString('shop_address') ?? '';
    final businessType = prefs.getString('business_type') ?? '';
    final shopPhone = prefs.getString('shop_phone') ?? '';
    
    final sb = StringBuffer();
    sb.write("Your shop name is '$shopName'.");
    if (businessType.isNotEmpty) sb.write(" It is a $businessType business.");
    if (shopAddress.isNotEmpty) sb.write(" Located at: $shopAddress.");
    if (shopPhone.isNotEmpty) sb.write(" Phone: $shopPhone.");
    return sb.toString();
  }

  Future<String> _buildSalesContext(int branchId, String query) async {
    final bool isOldSales = query.contains("old") || query.contains("history") || query.contains("yesterday") || query.contains("all");
    
    // QuickBill doesn't have getAllSales right now, but we can fake it or say we don't have historical data yet
    // Wait, let's gracefully handle historical queries.
    if (isOldSales) {
       return "For historical sales data, please visit the 'Reports' dashboard. Currently, I am optimized to report on live sales for today.";
    }

    final salesToday = await _dbService.getSalesToday(branchId);
    
    double totalRevenue = 0;
    for (var sale in salesToday) {
      totalRevenue += sale.total;
    }
    
    if (salesToday.isEmpty) {
      return "You haven't made any sales yet today.";
    }
    return "Your total sales for today are Rs. ${totalRevenue.toStringAsFixed(2)} across ${salesToday.length} bills.";
  }

  Future<String> _buildInventoryContext(int branchId, bool onlyLowStock) async {
    List<Product> products;
    if (onlyLowStock) {
      products = await _dbService.getLowStockProducts(branchId);
    } else {
      products = await _dbService.getAllProducts(branchId);
    }
    
    if (products.isEmpty) {
      if (onlyLowStock) return "Good news! You have no items running low on stock right now.";
      return "Your inventory is currently empty.";
    }

    final StringBuffer sb = StringBuffer();
    if (onlyLowStock) {
      sb.write("You have ${products.length} items running low on stock. Some of these include: ");
    } else {
      sb.write("You currently have ${products.length} products in your inventory. Some top items include: ");
    }
    
    for (int i = 0; i < products.length && i < 5; i++) {
      sb.write("${products[i].name}");
      if (i < products.length - 1 && i < 4) sb.write(", ");
    }
    sb.write(".");

    return sb.toString();
  }
  /// Builds a rich combined context of ALL shop data for use with Gemma AI.
  /// Gemma can then reason over the full picture and answer any question.
  Future<String> buildFullContext(int branchId) async {
    final sb = StringBuffer();
    
    try {
      // 1. SHOP PROFILE — read from SharedPreferences (the real source of truth)
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name') ?? 'Main Branch';
      final shopAddress = prefs.getString('shop_address') ?? '';
      final businessType = prefs.getString('business_type') ?? '';
      final shopPhone = prefs.getString('shop_phone') ?? '';
      
      sb.writeln('<SHOP_PROFILE>');
      sb.writeln('Shop Name: $shopName');
      if (businessType.isNotEmpty) sb.writeln('Business Type: $businessType');
      if (shopAddress.isNotEmpty) sb.writeln('Location: $shopAddress');
      if (shopPhone.isNotEmpty) sb.writeln('Phone: $shopPhone');
      sb.writeln('</SHOP_PROFILE>\n');
    } catch (_) {}

    try {
      // 2. LIVE SALES SUMMARY
      final salesToday = await _dbService.getSalesToday(branchId);
      double todayRevenue = 0;
      for (var s in salesToday) { todayRevenue += s.total; }

      if (salesToday.isNotEmpty) {
        sb.writeln('<TODAY_SALES>');
        sb.writeln('Bills Count: ${salesToday.length}');
        sb.writeln('Total Revenue: Rs. ${todayRevenue.toStringAsFixed(2)}');
        sb.writeln('</TODAY_SALES>\n');
      } else {
        sb.writeln('<SALES_INFO>No sales have been recorded for today yet.</SALES_INFO>\n');
      }
    } catch (_) {}

    try {
      // 3. INVENTORY & STOCK
      final lowStock = await _dbService.getLowStockProducts(branchId);
      final allProducts = await _dbService.getAllProducts(branchId);
      
      sb.writeln('<INVENTORY_SUMMARY>');
      if (allProducts.isEmpty) {
        sb.writeln('Status: The inventory is currently empty.');
      } else {
        sb.writeln('Total Products: ${allProducts.length}');
        if (lowStock.isNotEmpty) {
          sb.writeln('Low Stock Alert: ${lowStock.length} items are running low.');
          sb.writeln('Critical Items: ' + lowStock.take(5).map((p) => '${p.name} (qty: ${p.calculatedStock})').join(', '));
        } else {
          sb.writeln('Stock Status: All items are healthy.');
        }
        
        sb.writeln('Sample Inventory: ' + allProducts.take(5).map((p) => '${p.name} (Rs.${p.price})').join(', '));
      }
      sb.writeln('</INVENTORY_SUMMARY>\n');
    } catch (_) {}

    try {
      // 4. TOP PERFORMING
      final topSelling = await _dbService.getTopSellingProducts(
          5, 
          DateTime.now().subtract(const Duration(days: 30)), 
          DateTime.now(), 
          branchId);
      if (topSelling.isNotEmpty) {
        sb.writeln('<TOP_PRODUCTS>');
        sb.writeln('Trending: ' + topSelling.map((p) => p['product_name']).join(', '));
        sb.writeln('</TOP_PRODUCTS>\n');
      }
    } catch (_) {}

    return sb.toString();
  }
}

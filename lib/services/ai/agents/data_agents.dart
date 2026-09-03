import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/database_service.dart';
import 'base_agent.dart';

/// Retrieves shop identity data from SharedPreferences.
class ProfileAgent extends BaseAgent {
  @override
  String get name => 'ProfileAgent';

  @override
  String get description => 'Shop name, address, business type, contact info';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name') ?? '';
      final address = prefs.getString('shop_address') ?? '';
      final businessType = prefs.getString('business_type') ?? '';
      final phone = prefs.getString('shop_phone') ?? '';

      if (shopName.isEmpty) return AgentResult.empty(name);

      final sb = StringBuffer();
      sb.writeln('**SHOP PROFILE:**');
      sb.writeln('- **Name:** $shopName');
      if (businessType.isNotEmpty) sb.writeln('- **Type:** $businessType');
      if (address.isNotEmpty) sb.writeln('- **Address:** $address');
      if (phone.isNotEmpty) sb.writeln('- **Phone:** $phone');

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Retrieves comprehensive sales aggregations (Today, Month, All-Time) from SQLite.
class SalesAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'SalesAgent';

  @override
  String get description => 'Sales revenue, bill counts for today, this month, and all-time';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final db = await _db.database;
      final today = DateTime.now();

      // 1. Today's sales
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final todayResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total), 0) as rev 
        FROM sales WHERE branch_id = ? AND deleted = 0 AND created_at >= ?
      ''', [context.branchId, startOfDay]);
      int todayCount = todayResult.first['cnt'] as int? ?? 0;
      double todayRev = (todayResult.first['rev'] as num?)?.toDouble() ?? 0.0;

      // 2. This month's sales
      final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();
      final monthResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total), 0) as rev 
        FROM sales WHERE branch_id = ? AND deleted = 0 AND created_at >= ?
      ''', [context.branchId, startOfMonth]);
      int monthCount = monthResult.first['cnt'] as int? ?? 0;
      double monthRev = (monthResult.first['rev'] as num?)?.toDouble() ?? 0.0;

      // 3. All-time sales
      final allTimeResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total), 0) as rev 
        FROM sales WHERE branch_id = ? AND deleted = 0
      ''', [context.branchId]);
      int allTimeCount = allTimeResult.first['cnt'] as int? ?? 0;
      double allTimeRev = (allTimeResult.first['rev'] as num?)?.toDouble() ?? 0.0;

      final sb = StringBuffer();
      sb.writeln('**SALES SUMMARY:**');
      if (allTimeCount == 0) {
        sb.writeln('- *No sales have been recorded yet.*');
      } else {
        sb.writeln('- **Today:** $todayCount bills, **Rs. ${todayRev.toStringAsFixed(2)}** revenue');
        sb.writeln('- **This Month:** $monthCount bills, **Rs. ${monthRev.toStringAsFixed(2)}** revenue');
        sb.writeln('- **All Time:** $allTimeCount bills, **Rs. ${allTimeRev.toStringAsFixed(2)}** revenue');
      }

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Retrieves current inventory and low-stock alerts from SQLite.
class InventoryAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'InventoryAgent';

  @override
  String get description => 'Product count, low stock items, inventory overview';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final allProducts = await _db.getAllProducts(context.branchId);
      final lowStock = await _db.getLowStockProducts(context.branchId);

      final sb = StringBuffer();
      sb.writeln('**INVENTORY OVERVIEW:**');
      if (allProducts.isEmpty) {
        sb.writeln('- *Inventory is empty.*');
      } else {
        sb.writeln('- **Total Products:** ${allProducts.length}');
        if (lowStock.isNotEmpty) {
          sb.writeln('- ⚠️ **Low Stock Items (${lowStock.length}):** '
              '${lowStock.take(5).map((p) => '${p.name} (${p.calculatedStock} left)').join(', ')}');
        } else {
          sb.writeln('- *All items are well-stocked.*');
        }
        sb.writeln('- **Sample Products:** '
            '${allProducts.take(5).map((p) => '${p.name} @ Rs.${p.price}').join(', ')}');
      }

      return AgentResult(agentName: name, data: sb.toString(), hasData: allProducts.isNotEmpty);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Retrieves top-selling products from SQLite.
class TopProductsAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'TopProductsAgent';

  @override
  String get description => 'Best-selling products and trending items';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final top = await _db.getTopSellingProducts(5, thirtyDaysAgo, DateTime.now(), context.branchId);
      if (top.isEmpty) return AgentResult.empty(name);

      final sb = StringBuffer();
      sb.writeln('**TOP SELLING PRODUCTS:**');
      for (int i = 0; i < top.length; i++) {
        sb.writeln('${i + 1}. **${top[i]['product_name']}** — ${top[i]['total_quantity']} units sold');
      }

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Retrieves customer data, top debtors, and total outstanding debt.
class CustomerAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'CustomerAgent';

  @override
  String get description => 'Customer list, top debtors, and total outstanding debt';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final db = await _db.database;
      
      final aggResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total_debt), 0) as debt 
        FROM customers WHERE deleted = 0
      ''');
      
      int count = aggResult.first['cnt'] as int? ?? 0;
      double totalDebt = (aggResult.first['debt'] as num?)?.toDouble() ?? 0.0;

      final topDebtorsResult = await db.rawQuery('''
        SELECT name, phone, total_debt 
        FROM customers 
        WHERE deleted = 0 AND total_debt > 0
        ORDER BY total_debt DESC
        LIMIT 5
      ''');

      final sb = StringBuffer();
      sb.writeln('**CUSTOMER & DEBT SUMMARY:**');
      sb.writeln('- **Total Customers:** $count');
      sb.writeln('- **Total Outstanding Debt:** Rs. ${totalDebt.toStringAsFixed(2)}');
      
      if (topDebtorsResult.isNotEmpty) {
        sb.writeln('- **Top Debtors:**');
        for (var row in topDebtorsResult) {
          final debt = (row['total_debt'] as num?)?.toDouble() ?? 0.0;
          final phone = row['phone']?.toString().isNotEmpty == true ? row['phone'] : 'No phone';
          sb.writeln('  - **${row['name']}**: Rs. ${debt.toStringAsFixed(2)} ($phone)');
        }
      } else {
        sb.writeln('- *No customers currently owe money.*');
      }

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Retrieves expense data for today and this month.
class ExpenseAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'ExpenseAgent';

  @override
  String get description => 'Shop operational expenses and costs';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final db = await _db.database;
      final today = DateTime.now();

      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final todayResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total 
        FROM expenses 
        WHERE branch_id = ? AND deleted = 0 AND date >= ?
      ''', [context.branchId, startOfDay]);
      
      double todayTotal = (todayResult.first['total'] as num?)?.toDouble() ?? 0.0;

      final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();
      final monthResult = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total 
        FROM expenses 
        WHERE branch_id = ? AND deleted = 0 AND date >= ?
      ''', [context.branchId, startOfMonth]);
      
      double monthTotal = (monthResult.first['total'] as num?)?.toDouble() ?? 0.0;

      final sb = StringBuffer();
      sb.writeln('**EXPENSES SUMMARY:**');
      sb.writeln('- **Today\'s Expenses:** Rs. ${todayTotal.toStringAsFixed(2)}');
      sb.writeln('- **This Month\'s Expenses:** Rs. ${monthTotal.toStringAsFixed(2)}');

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

/// Generates a shopping list of low stock items and estimated restock costs.
class AutoRestockAgent extends BaseAgent {
  final DatabaseService _db = DatabaseService.instance;

  @override
  String get name => 'AutoRestockAgent';

  @override
  String get description => 'Automated shopping list of low stock items and estimated costs';

  @override
  Future<AgentResult> execute(AgentContext context) async {
    try {
      final db = await _db.database;

      final lowStockResult = await db.rawQuery('''
        SELECT name, stock, min_stock, cost_price 
        FROM products 
        WHERE branch_id = ? AND deleted = 0 AND stock <= min_stock
        ORDER BY stock ASC
      ''', [context.branchId]);
      
      if (lowStockResult.isEmpty) return AgentResult.empty(name);

      double estimatedRestockCost = 0;
      final sb = StringBuffer();
      sb.writeln('**RESTOCK SHOPPING LIST:**');
      
      for (var row in lowStockResult) {
        final name = row['name'];
        final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
        final targetInfo = row['min_stock'] != null ? ' (Target: ${row['min_stock']})' : '';
        
        final costPrice = (row['cost_price'] as num?)?.toDouble() ?? 0.0;
        final minStock = (row['min_stock'] as num?)?.toDouble() ?? 0.0;
        
        double deficit = minStock - stock;
        if (deficit <= 0) deficit = 10; // Default buffer if min_stock is 0
        
        if (costPrice > 0) estimatedRestockCost += (deficit * costPrice);

        sb.writeln('- **$name**: Only $stock left$targetInfo');
      }
      
      if (estimatedRestockCost > 0) {
        sb.writeln('\n- **Estimated Restock Cost:** Rs. ${estimatedRestockCost.toStringAsFixed(2)}');
      }

      return AgentResult(agentName: name, data: sb.toString(), hasData: true);
    } catch (e) {
      return AgentResult.empty(name);
    }
  }
}

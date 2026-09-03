import 'agents/base_agent.dart';

/// Merges the outputs of all agents into a single structured context string
/// that can be presented to the user directly or passed to InsightsAgent (Gemma).
class ResponseSynthesizer {
  /// Combines agent results into a clean, structured data block.
  /// Returns null if no agent produced data.
  String? synthesize(List<AgentResult> results) {
    final relevant = results.where((r) => r.hasData).toList();
    if (relevant.isEmpty) return null;

    final sb = StringBuffer();
    for (final result in relevant) {
      sb.writeln(result.data);
    }
    return sb.toString().trim();
  }

  /// Builds a single direct answer for factual single-agent queries
  /// (e.g. "what is my shop name?" → just return the ProfileAgent data directly).
  String? buildDirectAnswer(List<AgentResult> results, String query) {
    final lower = query.toLowerCase();

    // Shop name/profile — direct ProfileAgent answer
    if (_isOnlyProfileQuery(lower) && results.any((r) => r.agentName == 'ProfileAgent' && r.hasData)) {
      final profile = results.firstWhere((r) => r.agentName == 'ProfileAgent');
      return _extractShopProfileAnswer(profile.data, lower);
    }

    // Pure sales query — direct SalesAgent answer
    if (_isOnlySalesQuery(lower) && results.any((r) => r.agentName == 'SalesAgent' && r.hasData)) {
      final sales = results.firstWhere((r) => r.agentName == 'SalesAgent');
      return _extractSalesAnswer(sales.data);
    }

    // Pure inventory query — direct InventoryAgent answer
    if (_isOnlyInventoryQuery(lower) && results.any((r) => r.agentName == 'InventoryAgent' && r.hasData)) {
      final inv = results.firstWhere((r) => r.agentName == 'InventoryAgent');
      return _extractInventoryAnswer(inv.data, lower);
    }

    // Pure customer query
    if (_isOnlyCustomerQuery(lower) && results.any((r) => r.agentName == 'CustomerAgent' && r.hasData)) {
      final customer = results.firstWhere((r) => r.agentName == 'CustomerAgent');
      return _extractCustomerAnswer(customer.data);
    }

    // Pure expense query
    if (_isOnlyExpenseQuery(lower) && results.any((r) => r.agentName == 'ExpenseAgent' && r.hasData)) {
      final exp = results.firstWhere((r) => r.agentName == 'ExpenseAgent');
      return _extractExpenseAnswer(exp.data);
    }

    // Pure restock query
    if (_isOnlyRestockQuery(lower) && results.any((r) => r.agentName == 'AutoRestockAgent' && r.hasData)) {
      final restock = results.firstWhere((r) => r.agentName == 'AutoRestockAgent');
      return _extractRestockAnswer(restock.data);
    }

    return null; // Multi-agent → needs synthesized context → pass to Gemma
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  bool _isOnlyProfileQuery(String q) =>
      (q.contains('shop name') || q.contains('my name') || q.contains('shop address') ||
       q.contains('who are') || q.contains('business type') || q.contains('phone')) &&
      !q.contains('sale') && !q.contains('stock');

  bool _isOnlySalesQuery(String q) =>
      (q.contains('sale') || q.contains('revenue') || q.contains('bill') ||
       q.contains('how much') || q.contains('earn')) &&
      !q.contains('stock') && !q.contains('product') &&
      !q.contains('how to') && !q.contains('improve');

  bool _isOnlyInventoryQuery(String q) =>
      (q.contains('stock') || q.contains('inventory') || q.contains('item') || q.contains('product')) &&
      !q.contains('sale') && !q.contains('how to') && !q.contains('improve');

  bool _isOnlyCustomerQuery(String q) =>
      (q.contains('customer') || q.contains('debt') || q.contains('owe') || q.contains('client')) &&
      !q.contains('sale') && !q.contains('how to') && !q.contains('improve');

  bool _isOnlyExpenseQuery(String q) =>
      (q.contains('expense') || q.contains('cost') || q.contains('spend') || q.contains('spent')) &&
      !q.contains('sale') && !q.contains('how to') && !q.contains('improve');

  bool _isOnlyRestockQuery(String q) =>
      (q.contains('restock') || q.contains('shopping') || q.contains('buy') || q.contains('order')) &&
      !q.contains('sale') && !q.contains('how to') && !q.contains('improve');

  String _extractShopProfileAnswer(String data, String query) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (query.contains('name')) {
      final nameLine = lines.firstWhere(
        (l) => l.contains('Name:'), orElse: () => lines.first);
      return nameLine.replaceFirst('- **Name:**', 'Your shop name is').trim();
    }
    if (query.contains('address') || query.contains('location')) {
      final addrLine = lines.firstWhere(
        (l) => l.contains('Address:'), orElse: () => 'Address not set.');
      return addrLine.replaceFirst('- **Address:**', 'Your shop is located at').trim();
    }
    // Full profile
    return lines.where((l) => !l.contains('**SHOP PROFILE:**')).join('\n');
  }

  String _extractSalesAnswer(String data) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty && !l.contains("**SALES SUMMARY:**")).toList();
    return lines.map((l) => l.trim()).join('\n');
  }

  String _extractInventoryAnswer(String data, String query) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty && !l.contains('**INVENTORY OVERVIEW:**')).toList();
    if (query.contains('low')) {
      final low = lines.firstWhere((l) => l.contains('Low Stock') || l.contains('well-stocked'), orElse: () => lines.first);
      return low.trim();
    }
    return lines.map((l) => l.trim()).join('\n');
  }

  String _extractCustomerAnswer(String data) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty && !l.contains('**CUSTOMER & DEBT SUMMARY:**')).toList();
    return lines.map((l) => l.trim()).join('\n');
  }

  String _extractExpenseAnswer(String data) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty && !l.contains('**EXPENSES SUMMARY:**')).toList();
    return lines.map((l) => l.trim()).join('\n');
  }

  String _extractRestockAnswer(String data) {
    final lines = data.split('\n').where((l) => l.trim().isNotEmpty && !l.contains('**RESTOCK SHOPPING LIST:**')).toList();
    return lines.map((l) => l.trim()).join('\n');
  }
}

enum AIIntent {
  salesReport,
  inventoryStatus,
  companyProfile,
  lowStockAlerts,
  generalChat
}

class AIIntentRouter {
  /// Simple keyword matching to route queries to the correct data-fetching logic
  static AIIntent determineIntent(String query) {
    final lower = query.toLowerCase();
    
    // Priority 0: Advice/open-ended questions → Always use Gemma
    // Even if query contains 'sale'/'stock', these need reasoning not lookup
    final adviceKeywords = ['how to', 'how can', 'improve', 'increase', 'decrease',
      'tips', 'advice', 'suggest', 'strategy', 'help me', 'what should',
      'why is', 'why are', 'what is this', 'explain', 'tell me about'];
    if (adviceKeywords.any((kw) => lower.contains(kw))) {
      return AIIntent.generalChat;
    }

    // Priority 1: Identity / Company Info
    if (lower.contains('shop') || lower.contains('my name') || 
        lower.contains('location') || lower.contains('address') || 
        lower.contains('who are you') || lower.contains('business type')) {
      return AIIntent.companyProfile;
    }

    // Priority 2: Sales & Revenue (direct factual lookup)
    if (lower.contains('sale') || lower.contains('revenue') || 
        lower.contains('sold') || lower.contains('profit') || 
        lower.contains('money') || lower.contains('bill') ||
        lower.contains('earning')) {
      return AIIntent.salesReport;
    } 

    // Priority 3: Inventory & Stock (direct factual lookup)
    if (lower.contains('stock') || lower.contains('inventory') || 
        lower.contains('product') || lower.contains('item')) {
      if (lower.contains('low') || lower.contains('empty') || 
          lower.contains('out of') || lower.contains('shortage')) {
        return AIIntent.lowStockAlerts;
      }
      return AIIntent.inventoryStatus;
    }
    
    return AIIntent.generalChat;
  }
}

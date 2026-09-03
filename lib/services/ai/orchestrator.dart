import 'package:flutter/foundation.dart';
import '../../models/ai_message.dart';
import 'agents/base_agent.dart';
import 'agents/data_agents.dart';

/// Defines which combination of agents should handle a given query.
class AgentPlan {
  final List<BaseAgent> agents;
  final bool needsGemmaInsights;

  const AgentPlan({required this.agents, this.needsGemmaInsights = false});
}

/// The Orchestrator analyses the user query and selects the right agents.
/// It then runs the selected agents in parallel to minimise latency.
class AIOrchestrator {
  // Singleton agent instances (reused across queries)
  static final _profileAgent     = ProfileAgent();
  static final _salesAgent       = SalesAgent();
  static final _inventoryAgent   = InventoryAgent();
  static final _topProductsAgent = TopProductsAgent();
  static final _customerAgent    = CustomerAgent();
  static final _expenseAgent     = ExpenseAgent();
  static final _restockAgent     = AutoRestockAgent();

  /// Advice/open-ended keywords → always add Gemma insights
  static const _insightKeywords = [
    'how to', 'how can', 'improve', 'increase', 'decrease', 'tips',
    'advice', 'suggest', 'strategy', 'help me', 'what should',
    'why is', 'why are', 'explain', 'analyse', 'analyze', 'summary',
    'overview', 'full report', 'tell me about', 'what do you think',
  ];

  /// Selects + builds the agent plan for a given user query.
  AgentPlan plan(String query, {List<AIMessage> history = const []}) {
    final lower = query.toLowerCase();

    final bool wantsInsights = _insightKeywords.any((kw) => lower.contains(kw));
    
    // Core intents
    final bool wantsSales    = lower.contains('sale') || lower.contains('revenue') ||
        lower.contains('bill') || lower.contains('profit') || lower.contains('earning') ||
        lower.contains('how much') || lower.contains('money');
    final bool wantsInventory = lower.contains('stock') || lower.contains('inventory') ||
        lower.contains('product') || lower.contains('item') || lower.contains('low');
    final bool wantsProfile   = lower.contains('shop') || lower.contains('my name') ||
        lower.contains('address') || lower.contains('business');
    final bool wantsTopItems  = lower.contains('top') || lower.contains('best') ||
        lower.contains('popular') || lower.contains('trending');
    final bool wantsFullReport = lower.contains('full') || lower.contains('report') ||
        lower.contains('overview') || lower.contains('summary');
        
    // New Action Intents
    final bool wantsCustomer = lower.contains('customer') || lower.contains('debt') ||
        lower.contains('owe') || lower.contains('who') || lower.contains('client');
    final bool wantsExpense  = lower.contains('expense') || lower.contains('cost') ||
        lower.contains('spend') || lower.contains('spent') || lower.contains('profit');
    final bool wantsRestock  = lower.contains('restock') || lower.contains('shopping') ||
        lower.contains('order') || lower.contains('buy') || lower.contains('purchase') ||
        lower.contains('need to get');

    final agents = <BaseAgent>[];

    // Full report → invoke all main agents
    if (wantsFullReport) {
      return AgentPlan(
        agents: [_profileAgent, _salesAgent, _inventoryAgent, _expenseAgent, _customerAgent],
        needsGemmaInsights: true,
      );
    }

    if (wantsProfile)   agents.add(_profileAgent);
    if (wantsSales)     agents.add(_salesAgent);
    if (wantsInventory) agents.add(_inventoryAgent);
    if (wantsTopItems)  agents.add(_topProductsAgent);
    if (wantsCustomer)  agents.add(_customerAgent);
    if (wantsExpense)   agents.add(_expenseAgent);
    if (wantsRestock) {
      agents.add(_restockAgent);
      if (!agents.contains(_inventoryAgent)) agents.add(_inventoryAgent); // Pair them up
    }

    // Advice queries without explicit domain → invoke core data agents
    if (wantsInsights && agents.isEmpty) {
      agents.addAll([_salesAgent, _inventoryAgent, _customerAgent, _expenseAgent]);
    }
    // Advice queries WITH a domain → add top products for extra context if sales are mentioned
    if (wantsInsights && wantsSales && !agents.contains(_topProductsAgent)) {
      agents.add(_topProductsAgent);
    }

    // Continuation Logic: if query is very short/ambiguous, check history
    final bool isVeryShort = lower.split(' ').length <= 2;
    if (isVeryShort && agents.isEmpty && history.isNotEmpty) {
      final lastAiMsg = history.lastWhere((m) => !m.isUser, orElse: () => AIMessage(text: '', isUser: false)).text.toLowerCase();
      
      // If AI just offered tips or analysis, continue that context
      if (lastAiMsg.contains('tip') || lastAiMsg.contains('insight') || lastAiMsg.contains('summariz')) {
        agents.addAll([_salesAgent, _inventoryAgent, _expenseAgent]);
        return AgentPlan(agents: agents, needsGemmaInsights: true);
      }
    }

    // Default fallback: only default to SalesAgent if the query is not a greeting/conversational/short query
    if (agents.isEmpty) {
      final greetingKeywords = ['hello', 'hi', 'hey', 'yo', 'hola', 'greetings', 'welcome', 'morning', 'afternoon', 'evening', 'what', 'happend', 'happened', 'help'];
      final isGreetingOrGeneral = greetingKeywords.any((kw) => lower.contains(kw)) || isVeryShort;
      if (!isGreetingOrGeneral) {
        agents.add(_salesAgent);
      }
    }

    return AgentPlan(agents: agents, needsGemmaInsights: wantsInsights);
  }

  /// Runs all agents in the plan **in parallel** and returns their results.
  Future<List<AgentResult>> run(AgentPlan plan, AgentContext context) async {
    debugPrint('🤖 Orchestrator: running ${plan.agents.map((a) => a.name).join(', ')}');
    final futures = plan.agents.map((agent) async {
      try {
        final result = await agent.execute(context);
        debugPrint('  ✅ ${agent.name}: hasData=${result.hasData}');
        return result;
      } catch (e) {
        debugPrint('  ❌ ${agent.name} failed: $e');
        return AgentResult.empty(agent.name);
      }
    });
    return Future.wait(futures);
  }
}

import '../../../models/ai_message.dart';

/// Represents the input context passed to every agent.
class AgentContext {
  final String userQuery;
  final int branchId;
  final List<AIMessage> history;

  const AgentContext({
    required this.userQuery,
    required this.branchId,
    this.history = const [],
  });
}

/// The output produced by a single agent after execution.
class AgentResult {
  /// Human-readable agent name (for synthesizer labelling).
  final String agentName;

  /// The structured data string this agent retrieved.
  final String data;

  /// Whether this agent actually found relevant data.
  final bool hasData;

  /// How confident this agent is that it should be used (0.0 – 1.0).
  final double confidence;

  const AgentResult({
    required this.agentName,
    required this.data,
    required this.hasData,
    this.confidence = 1.0,
  });

  static AgentResult empty(String agentName) =>
      AgentResult(agentName: agentName, data: '', hasData: false, confidence: 0.0);
}

/// Contract every specialised agent must fulfil.
abstract class BaseAgent {
  /// Short identifier used in logs and the synthesizer.
  String get name;

  /// Description of what this agent knows about.
  String get description;

  /// Execute the agent and return its result.
  Future<AgentResult> execute(AgentContext context);
}

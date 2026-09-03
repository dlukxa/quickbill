class AIMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? suggestedAction;

  AIMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.suggestedAction,
  }) : timestamp = timestamp ?? DateTime.now();
}

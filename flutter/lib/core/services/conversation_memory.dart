class ConversationMemory {
  final List<Map<String, String>> _turns = [];
  String lastScene = '';

  List<Map<String, String>> get history => List.unmodifiable(_turns);
  String lastReply = '';

  void rememberScene(String summary) {
    final clipped = summary.trim();
    if (clipped.isEmpty) {
      return;
    }
    lastScene = clipped;
  }

  void addTurn({required String user, required String assistant}) {
    if (user.trim().isNotEmpty) {
      _turns.add({'role': 'user', 'content': user.trim()});
    }
    if (assistant.trim().isNotEmpty) {
      _turns.add({'role': 'assistant', 'content': assistant.trim()});
      lastReply = assistant.trim();
    }
    while (_turns.length > 6) {
      _turns.removeAt(0);
    }
  }
}

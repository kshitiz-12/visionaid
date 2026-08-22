import 'prioritized_object.dart';

class ContextDecision {
  const ContextDecision({
    required this.shouldSpeak,
    required this.spokenMessage,
    required this.ranked,
    required this.reason,
  });

  final bool shouldSpeak;
  final String spokenMessage;
  final List<PrioritizedObject> ranked;
  final String reason;
}

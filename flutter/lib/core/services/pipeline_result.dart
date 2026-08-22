import '../../features/intent/domain/entities/user_intent.dart';
import '../../features/context_engine/domain/entities/context_decision.dart';

class PipelineResult {
  const PipelineResult({
    required this.intent,
    required this.spokenReply,
    this.decision,
    this.isAlert = false,
  });

  final UserIntent intent;
  final String spokenReply;
  final ContextDecision? decision;
  final bool isAlert;
}

class VoiceContext {
  const VoiceContext({
    required this.intent,
    required this.location,
    required this.userMood,
    required this.environment,
    required this.urgency,
    required this.target,
  });

  final String intent;
  final String location;
  final String userMood;
  final String environment;
  final String urgency;
  final String target;

  bool get isReady => intent.isNotEmpty && environment.isNotEmpty;
}

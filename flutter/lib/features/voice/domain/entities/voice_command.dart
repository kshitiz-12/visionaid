class VoiceCommand {
  const VoiceCommand({
    required this.rawText,
    required this.intent,
    required this.confidence,
    required this.isActionable,
  });

  final String rawText;
  final String intent;
  final double confidence;
  final bool isActionable;

  bool get isValid => rawText.trim().isNotEmpty && confidence >= 0.0;
}

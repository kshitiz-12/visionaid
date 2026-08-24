/// Strips Markdown / markup so native TTS speaks clean sentences.
class SpeechSanitizer {
  SpeechSanitizer._();

  static String clean(String raw) {
    var text = raw.trim();
    if (text.isEmpty) {
      return text;
    }
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'[#*_>~]'), '');
    text = text.replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }
}

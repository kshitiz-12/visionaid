/// Splits streaming assistant text into speakable sentences.
class SentenceBuffer {
  String _buf = '';

  List<String> add(String delta) {
    _buf += delta;
    final out = <String>[];
    while (true) {
      final end = _sentenceEnd(_buf);
      if (end < 0) {
        break;
      }
      final sentence = _buf.substring(0, end + 1).trim();
      _buf = _buf.substring(end + 1);
      if (sentence.isNotEmpty) {
        out.add(sentence);
      }
    }
    return out;
  }

  String flush() {
    final leftover = _buf.trim();
    _buf = '';
    return leftover;
  }

  static int _sentenceEnd(String text) {
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final stop = ch == '.' || ch == '!' || ch == '?' || ch == '।';
      if (!stop) {
        continue;
      }
      if (ch == '.' && i > 0 && _isDigit(text[i - 1])) {
        continue;
      }
      if (i + 1 >= text.length || text[i + 1] == ' ' || text[i + 1] == '\n') {
        return i;
      }
    }
    // Hindi/English mix often has no period until the end. Speak a clause.
    if (text.trim().length >= 70) {
      final space = text.lastIndexOf(' ');
      if (space >= 40) {
        return space - 1;
      }
    }
    return -1;
  }

  static bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
}

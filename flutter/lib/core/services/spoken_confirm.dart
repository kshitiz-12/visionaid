class SpokenConfirm {
  SpokenConfirm._();

  static String _fold(String spoken) {
    return spoken
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _hasToken(String text, String token) {
    if (token.isEmpty) {
      return false;
    }
    if (RegExp(r'^[a-z0-9]+$').hasMatch(token)) {
      return RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(text);
    }
    return text.contains(token);
  }

  static bool isYes(String spoken) {
    final t = _fold(spoken);
    if (t.isEmpty) {
      return false;
    }
    const latin = [
      'yes',
      'yeah',
      'yep',
      'yup',
      'yea',
      'yah',
      'yesh',
      'correct',
      'confirm',
      'okay',
      'ok',
      'right',
      'sure',
      'affirmative',
      'haan',
      'haanji',
      'hanji',
      'han',
      'haa',
      'sahi',
      'theek',
      'thik',
      'bilkul',
    ];
    if (latin.any((w) => _hasToken(t, w))) {
      return true;
    }
    // Whole-word "ha" only — not inside "that" / "what".
    if (RegExp(r'(^|\s)ha(\s|$)').hasMatch(t)) {
      return true;
    }
    const native = [
      'हाँ',
      'हां',
      'हा',
      'जी',
      'सही',
      'ठीक',
      'येस',
      'यस',
      'येश',
      'हांजी',
      'हाँजी',
    ];
    return native.any(t.contains);
  }

  static bool isNo(String spoken) {
    final t = _fold(spoken);
    if (t.isEmpty) {
      return false;
    }
    const latin = [
      'no',
      'nope',
      'nah',
      'wrong',
      'again',
      'nahi',
      'nahee',
      'naa',
      'cancel',
      'negative',
    ];
    if (latin.any((w) => _hasToken(t, w))) {
      return true;
    }
    if (RegExp(r'(^|\s)na(\s|$)').hasMatch(t)) {
      return true;
    }
    const native = ['नहीं', 'नही', 'ना', 'मत', 'गलत', 'नो'];
    return native.any(t.contains);
  }

  static String? parseLanguage(String spoken) {
    final t = spoken.trim().toLowerCase();
    if (RegExp(r'\b(hindi|हिंदी|हिन्दी|हिन्दि)\b').hasMatch(t) ||
        t.contains('हिंदी') ||
        t.contains('हिन्दी')) {
      return 'hi';
    }
    if (RegExp(r'\b(english|angrezi|अंग्रेजी)\b').hasMatch(t) ||
        t.contains('अंग्रेजी')) {
      return 'en';
    }
    return null;
  }

  static int? choiceIndex(String spoken, int count) {
    final t = spoken.trim().toLowerCase();
    final ordered = <(RegExp, int)>[
      (RegExp(r'\b(3|three|third|तीसरा|तीन)\b'), 2),
      (RegExp(r'\b(2|two|second|दूसरा|दो)\b'), 1),
      (RegExp(r'\b(1|one|first|पहला|एक)\b'), 0),
    ];
    for (final row in ordered) {
      if (row.$2 < count && row.$1.hasMatch(t)) {
        return row.$2;
      }
    }
    return null;
  }

  static String digitsFromSpeech(String spoken) {
    var t = ' ${spoken.toLowerCase()} ';
    const words = <String, String>{
      'zero': '0',
      'oh': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'plus': '',
      'शून्य': '0',
      'एक': '1',
      'दो': '2',
      'तीन': '3',
      'चार': '4',
      'पांच': '5',
      'पाँच': '5',
      'छह': '6',
      'सात': '7',
      'आठ': '8',
      'नौ': '9',
    };
    for (final e in words.entries) {
      t = t.replaceAll(e.key, ' ${e.value} ');
    }
    return t.replaceAll(RegExp(r'[^\d]'), '');
  }
}

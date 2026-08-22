class SpokenConfirm {
  SpokenConfirm._();

  static bool isYes(String spoken) {
    final t = spoken.trim().toLowerCase();
    return RegExp(
      r'\b(yes|yeah|yep|correct|confirm|ok|okay|right|sure|haan|han|ha|sahi|theek|जी|हाँ|हां|सही|ठीक)\b',
    ).hasMatch(t);
  }

  static bool isNo(String spoken) {
    final t = spoken.trim().toLowerCase();
    return RegExp(
      r'\b(no|nope|wrong|again|nahi|na|cancel|नहीं|नही|गलत)\b',
    ).hasMatch(t);
  }

  static String? parseLanguage(String spoken) {
    final t = spoken.trim().toLowerCase();
    if (RegExp(r'\b(hindi|हिंदी|हिन्दी|हिन्दि)\b').hasMatch(t)) {
      return 'hi';
    }
    if (RegExp(r'\b(english|angrezi|angrezi|अंग्रेजी)\b').hasMatch(t)) {
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

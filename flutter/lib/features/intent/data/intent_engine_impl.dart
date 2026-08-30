import '../domain/entities/user_intent.dart';
import '../domain/services/intent_engine.dart';

/// Rule-based on-device intent router (privacy-first, offline).
class IntentEngineImpl implements IntentEngine {
  static final _patterns = <IntentType, List<RegExp>>{
    IntentType.quit: [
      RegExp(r'\b(quit|quiet|quite|exit|close\s+(the\s+)?app|shut\s+down)\b'),
      RegExp(r'बाहर\s*निकलो|ऐप\s*बंद|बंद\s*करो'),
    ],
    IntentType.cancel: [
      RegExp(
        r'\b(cancel|never\s*mind|go\s+home|stop\s+listening|stop\s+talking|stop\s+guiding|stop\s+walking|stop\s+looking)\b',
      ),
    ],
    IntentType.emergency: [
      RegExp(
        r'\b(emergency|emerjency|emargency|imergency|emergensi|danger|sos|i\s*am\s*hurt|i.?m\s*hurt|call\s*(for\s*)?help|call\s*me|phone\s*me|dial\s*me)\b',
      ),
      RegExp(r'^(help me|help me please)$'),
      RegExp(
        r'(आपातकाल|खतरा|इमरजेंसी|इमरजेन्सी|एमर्जेंसी|एमरजेंसी|बचाओ|मदद\s*करो)',
      ),
    ],
    IntentType.communication: [
      RegExp(
        r'\b(call|dial|whatsapp|wa\s*tsapp|message|text|sms)\b',
      ),
      RegExp(
        r'(कॉल|मैसेज|व्हाट्सऐप|व्हाट्सएप|फोन\s*(करो|लगाओ|लगा|करें)|मुझे\s*कॉल)',
      ),
      RegExp(r'\b(call|phone|dial)\s+(karo|kar|lagao|laga)\b'),
    ],
    IntentType.readText: [
      RegExp(
        r'\b(read\s+(this|that|the|it)|ocr|what\s+does\s+(this|it|the\s+sign)\s+say|read\s+(the\s+)?(text|sign|label|menu))\b',
      ),
      RegExp(r'\b(ये\s*पढ़ो|टेक्स्ट\s*पढ़ो|साइन\s*पढ़ो)\b'),
    ],
    IntentType.navigation: [
      RegExp(r'\b(guide\s+me|walk\s+with\s+me|live\s+guide|look\s+ahead)\b'),
      RegExp(r'\b(गाइड\s*मी|साथ\s*चलो|आगे\s*देखो)\b'),
    ],
    IntentType.routeNavigate: [
      RegExp(
        r'\b(navigate\s+to|take\s+me\s+to|directions?\s+to|walk\s+to|go\s+to)\b',
      ),
      RegExp(r'\b(ले\s*चलो|रास्ता\s*बताओ|नेविगेट)\b'),
    ],
    IntentType.findObject: [
      RegExp(
        r'\b(where\s+is(\s+my|\s+the)?|find(\s+my|\s+the)?|locate(\s+my|\s+the)?|look\s+for(\s+my|\s+the)?)\b',
      ),
      RegExp(r'\b(मेरा\s+.+\s+कहाँ|कहाँ\s*है\s*(मेरा|मेरी)|ढूँढो|खोजो)\b'),
    ],
    IntentType.sceneDescribe: [
      RegExp(
        r"\b(what('?s|\s+is)\s+(that|this|in\s+front|around\s+me)|what\s+do\s+you\s+see|describe\s+(the\s+)?(scene|room|view)|look\s+around|in\s+front\s+of\s+me|around\s+me)\b",
      ),
      RegExp(r'\b(क्या\s*दिख|ये\s*क्या\s*है|सामने\s*क्या|आसपास\s*क्या|दृश्य)\b'),
    ],
    IntentType.help: [
      RegExp(r'\b(what\s+can\s+you(\s+do)?|commands?|how\s+do\s+i\s+use)\b'),
      RegExp(r'\b(क्या\s*कर\s*सकते|कमांड)\b'),
    ],
  };

  static final _objectTargetPatterns = <String, RegExp>{
    'door': RegExp(r'\bdoors?\b|\bदरवाजा\b'),
    'sign': RegExp(r'\bsigns?\b|\bसाइन\b|\bबोर्ड\b'),
    'person': RegExp(r'\b(person|people|someone|man|woman)\b|\bव्यक्ति\b'),
    'chair': RegExp(r'\bchairs?\b|\bकुर्सी\b'),
    'table': RegExp(r'\btables?\b|\bमेज\b'),
    'phone': RegExp(r'\bphones?\b|\bफोन\b'),
    'laptop': RegExp(r'\b(laptops?|computer|notebook)\b|\bलैपटॉप\b'),
    'headphones': RegExp(r'\b(headphones?|earphones?|earbuds?|headset)\b|\bहेडफोन\b'),
    'purse': RegExp(r'\b(purse|handbag|wallet|bag)\b|\bपर्स\b|\bबैग\b'),
    'bottle': RegExp(r'\bbottles?\b|\bबोतल\b'),
    'keys': RegExp(r'\bkeys?\b|\bचाबी\b|\bचाबियाँ\b'),
      'shoes': RegExp(
        r'\b(shoes?|footwear|sneakers?|boots?|sandals?)\b|\bजूत[ेा]?\b|\bचप्पल\b',
      ),
      'vehicle': RegExp(r'\b(car|bus|truck|vehicle|bike)\b|\bगाड़ी\b|\bकार\b'),
    'stairs': RegExp(r'\bstairs?\b|\bसीढ़ि'),
    'exit': RegExp(r'\bexits?\b|\bनिकास\b'),
  };

  static final _routeDestination = RegExp(
    r'\b(?:navigate\s+to|take\s+me\s+to|directions?\s+to|walk\s+to|go\s+to)\s+(.+)$',
    caseSensitive: false,
  );

  static final _freeObjectTarget = RegExp(
    r'\b(?:find|locate|look\s+for|where\s+is)\s+(?:my\s+|the\s+)?(.+)$',
    caseSensitive: false,
  );

  static final _contactNamePattern = RegExp(
    r'\b(?:call|dial|phone|whatsapp|message|text|sms|send(?:\s+a)?(?:\s+whatsapp)?(?:\s+message)?(?:\s+sms)?|कॉल|मैसेज|फोन|व्हाट्सऐप)\s+(?:a\s+)?(?:message\s+|whatsapp\s+|sms\s+|text\s+)?(?:to\s+|को\s+)?(.+)$',
    caseSensitive: false,
  );

  static final _bodyPattern = RegExp(
    r'\b(?:saying|that|says|:)\s+(.+)$',
    caseSensitive: false,
  );

  static final _fillerTail = RegExp(
    r'\b(please|now|for\s+me|quickly|right\s+now|thanks|thank\s+you|on\s+whatsapp|via\s+whatsapp|on\s+sms)\b.*$',
    caseSensitive: false,
  );

  static const _ignoredContactTokens = {
    'me',
    'myself',
    'help',
    'someone',
    'somebody',
    'them',
    'him',
    'her',
    'a',
    'the',
    'my',
    'emergency',
    'contact',
    'number',
    'phone',
    'message',
    'whatsapp',
    'sms',
    'text',
    'send',
    'on',
    'via',
    'using',
    'karo',
    'kar',
    'lagao',
    'laga',
    'please',
    'करो',
    'लगाओ',
    'लगा',
    'को',
    'मुझे',
  };

  @override
  Future<UserIntent> classify(String spokenText) async {
    final normalized = spokenText.trim();
    if (normalized.isEmpty) {
      return const UserIntent(
        type: IntentType.unknown,
        rawText: '',
        confidence: 0,
        isActionable: false,
      );
    }

    final lower = normalized.toLowerCase();
    IntentType type = IntentType.unknown;
    double confidence = 0.45;

    for (final entry in _patterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lower)) {
          type = entry.key;
          confidence = entry.key == IntentType.emergency ? 0.97 : 0.9;
          break;
        }
      }
      if (type != IntentType.unknown) {
        break;
      }
    }

    if (type == IntentType.unknown) {
      type = IntentType.conversation;
      confidence = 0.55;
    }

    var isComm = type == IntentType.communication || type == IntentType.emergency;
    var contactName = isComm ? _extractContactName(lower) : '';
    if (type == IntentType.communication && _meansEmergencyContact(lower, contactName)) {
      type = IntentType.emergency;
      contactName = '';
      isComm = true;
    }
    final target = isComm
        ? ''
        : (type == IntentType.routeNavigate
            ? _extractRouteDestination(lower)
            : _extractObjectTarget(lower));
    final messageBody = isComm ? _extractBody(lower) : '';

    final commAction = switch (type) {
      IntentType.communication => _commAction(lower),
      IntentType.emergency => CommAction.call,
      _ => CommAction.none,
    };

    return UserIntent(
      type: type,
      rawText: normalized,
      confidence: confidence,
      target: target,
      contactName: contactName,
      messageBody: messageBody,
      commAction: commAction,
      isActionable: type != IntentType.cancel,
    );
  }

  bool _meansEmergencyContact(String lower, String contactName) {
    if (RegExp(r'\b(whatsapp|message|text|sms|मैसेज|व्हाट्सऐप)\b').hasMatch(lower)) {
      return false;
    }
    if (RegExp(
      r'\b(call\s*me|dial\s*me|phone\s*me|emergency|sos|call\s*(for\s*)?help)\b',
    ).hasMatch(lower)) {
      return true;
    }
    final name = contactName.trim().toLowerCase();
    if (name == 'me' ||
        name == 'myself' ||
        name == 'emergency' ||
        name.contains('emergency')) {
      return true;
    }
    // Bare "call" / "call karo" / "कॉल करो" with no person — not "call Ramesh".
    final bare = lower
        .replaceAll(RegExp(r'[?.!,]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty &&
        RegExp(
          r'^(call|dial|phone|कॉल)(\s+(karo|kar|lagao|laga|please|करो|लगाओ))?$',
        ).hasMatch(bare)) {
      return true;
    }
    return false;
  }

  CommAction _commAction(String lower) {
    if (RegExp(r'\b(whatsapp|व्हाट्सऐप|व्हाट्सएप)\b').hasMatch(lower)) {
      return CommAction.whatsapp;
    }
    if (RegExp(r'\b(message|text|sms|send|मैसेज)\b').hasMatch(lower)) {
      return CommAction.sms;
    }
    return CommAction.call;
  }

  String _extractRouteDestination(String lower) {
    final match = _routeDestination.firstMatch(lower);
    if (match == null) {
      return '';
    }
    var name = (match.group(1) ?? '').trim();
    name = name.replaceAll(_fillerTail, '').trim();
    name = name.replaceAll(RegExp(r'[?.!,]+$'), '').trim();
    return name;
  }

  String _extractObjectTarget(String lower) {
    String best = '';
    var bestIndex = lower.length + 1;
    for (final entry in _objectTargetPatterns.entries) {
      final match = entry.value.firstMatch(lower);
      if (match != null && match.start < bestIndex) {
        bestIndex = match.start;
        best = entry.key;
      }
    }
    if (best.isNotEmpty) {
      return best;
    }
    final free = _freeObjectTarget.firstMatch(lower);
    if (free == null) {
      return '';
    }
    var name = (free.group(1) ?? '').trim();
    name = name.replaceAll(_fillerTail, '').trim();
    name = name.replaceAll(RegExp(r'[?.!,]+$'), '').trim();
    if (name.length < 2 || name.length > 40) {
      return '';
    }
    return name;
  }

  String _extractBody(String lower) {
    final match = _bodyPattern.firstMatch(lower);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractContactName(String lower) {
    var working = lower;
    final body = _bodyPattern.firstMatch(working);
    if (body != null) {
      working = working.substring(0, body.start).trim();
    }

    var name = '';
    final hindiFirst = RegExp(
      r'^(.+?)\s+को\s+(?:कॉल|call|dial|phone)',
    ).firstMatch(working);
    if (hindiFirst != null) {
      name = hindiFirst.group(1)!.trim();
    } else {
      final match = _contactNamePattern.firstMatch(working);
      if (match != null) {
        name = match.group(1)!.trim();
      }
    }

    if (name.isEmpty) {
      return '';
    }

    name = name.replaceAll(_fillerTail, '').trim();
    name = name.replaceAll(RegExp(r'[?.!,]+$'), '').trim();

    if (name.contains('emergency') || name == 'contact') {
      return '';
    }

    final tokens = name
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_ignoredContactTokens.contains(t))
        .toList();

    return tokens.join(' ');
  }
}

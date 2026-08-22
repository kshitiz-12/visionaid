import '../domain/entities/user_intent.dart';
import '../domain/services/intent_engine.dart';

/// Rule-based on-device intent router (privacy-first, offline).
class IntentEngineImpl implements IntentEngine {
  static final _patterns = <IntentType, List<RegExp>>{
    IntentType.quit: [
      RegExp(r'\b(quit|exit|close\s+(the\s+)?app|shut\s+down)\b'),
      RegExp(r'\b(बाहर\s*निकलो|ऐप\s*बंद)\b'),
    ],
    IntentType.cancel: [
      RegExp(r'\b(cancel|never\s*mind|quiet|go\s+home|stop\s+listening|stop\s+talking)\b'),
    ],
    IntentType.emergency: [
      RegExp(r'\b(emergency|danger|sos|i\s*am\s*hurt|call\s*(for\s*)?help)\b'),
      RegExp(r'^(help me|help me please)$'),
      RegExp(r'\b(आपातकाल|खतरा)\b'),
    ],
    IntentType.communication: [
      RegExp(
        r'\b(call|dial|whatsapp|wa\s*tsapp|message|text|sms|send)\b',
      ),
      RegExp(r'\b(कॉल|मैसेज|फोन|व्हाट्सऐप|व्हाट्सएप)\b'),
    ],
    IntentType.readText: [
      RegExp(r'\b(read|ocr|what\s+does\s+it\s+say|read\s+(the\s+)?(text|sign|label|menu))\b'),
      RegExp(r'\b(पढ़ो|पढ़ना|लिख[ाई]|टेक्स्ट)\b'),
    ],
    IntentType.navigation: [
      RegExp(r'\b(navigat|take\s+me|find\s+(the\s+)?route|directions?|guide\s+me|walk\s+with\s+me)\b'),
      RegExp(r'\b(नेविगेट|ले\s*चलो|साथ\s*चलो)\b'),
    ],
    IntentType.findObject: [
      RegExp(r'\b(where\s+is|find|locate|look\s+for|search\s+for)\b'),
      RegExp(r'\b(कहाँ\s*है|ढूँढो|खोजो)\b'),
    ],
    IntentType.sceneDescribe: [
      RegExp(
        r'\b(what(\s+is|\s+do\s+you\s+see)|describe|in\s+front|around\s+me|look\s+around|scene)\b',
      ),
      RegExp(r'\b(क्या\s*(है|दिख|देख)|सामने|आसपास)\b'),
    ],
    IntentType.help: [
      RegExp(r'\b(help|what\s+can\s+you|commands?|how\s+do\s+i)\b'),
      RegExp(r'\b(मदद|कैसे|क्या\s*कर\s*सकते)\b'),
    ],
  };

  static final _objectTargetPatterns = <String, RegExp>{
    'door': RegExp(r'\bdoors?\b|\bदरवाजा\b'),
    'sign': RegExp(r'\bsigns?\b|\bसाइन\b|\bबोर्ड\b'),
    'person': RegExp(r'\b(person|people|someone|man|woman)\b|\bव्यक्ति\b'),
    'chair': RegExp(r'\bchairs?\b|\bकुर्सी\b'),
    'table': RegExp(r'\btables?\b|\bमेज\b'),
    'phone': RegExp(r'\bphones?\b|\bफोन\b'),
    'purse': RegExp(r'\b(purse|handbag|wallet|bag)\b|\bपर्स\b|\bबैग\b'),
    'vehicle': RegExp(r'\b(car|bus|truck|vehicle|bike)\b|\bगाड़ी\b|\bकार\b'),
    'stairs': RegExp(r'\bstairs?\b|\bसीढ़ि'),
    'exit': RegExp(r'\bexits?\b|\bनिकास\b'),
  };

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

    final isComm = type == IntentType.communication || type == IntentType.emergency;
    final target = isComm ? '' : _extractObjectTarget(lower);
    final contactName = isComm ? _extractContactName(lower) : '';
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

  CommAction _commAction(String lower) {
    if (RegExp(r'\b(whatsapp|व्हाट्सऐप|व्हाट्सएप)\b').hasMatch(lower)) {
      return CommAction.whatsapp;
    }
    if (RegExp(r'\b(message|text|sms|send|मैसेज)\b').hasMatch(lower)) {
      return CommAction.sms;
    }
    return CommAction.call;
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
    return best;
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

    final match = _contactNamePattern.firstMatch(working);
    if (match == null) {
      return '';
    }

    var name = match.group(1)!.trim();
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

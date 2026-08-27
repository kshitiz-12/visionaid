enum IntentType {
  sceneDescribe,
  findObject,
  readText,
  navigation,
  routeNavigate,
  communication,
  emergency,
  help,
  conversation,
  cancel,
  quit,
  unknown,
}

enum CommAction {
  none,
  call,
  sms,
  whatsapp,
}

class UserIntent {
  const UserIntent({
    required this.type,
    required this.rawText,
    required this.confidence,
    this.target = '',
    this.contactName = '',
    this.messageBody = '',
    this.commAction = CommAction.none,
    this.isActionable = true,
  });

  final IntentType type;
  final String rawText;
  final double confidence;
  final String target;
  final String contactName;
  final String messageBody;
  final CommAction commAction;
  final bool isActionable;

  String get routeKey => switch (type) {
        IntentType.sceneDescribe => 'vision',
        IntentType.findObject => 'vision',
        IntentType.readText => 'ocr',
        IntentType.navigation => 'navigation',
        IntentType.routeNavigate => 'route_navigate',
        IntentType.communication => 'communication',
        IntentType.emergency => 'emergency',
        IntentType.help => 'help',
        IntentType.conversation => 'conversation',
        IntentType.cancel => 'cancel',
        IntentType.quit => 'quit',
        IntentType.unknown => 'unknown',
      };
}

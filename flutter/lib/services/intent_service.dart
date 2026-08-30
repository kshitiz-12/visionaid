import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/config/app_config.dart';

/// One contact row for Gemini contact-resolution grounding.
class ContactRef {
  const ContactRef({
    required this.displayName,
    this.searchNames = const [],
    this.phoneLast4 = '',
  });

  final String displayName;
  final List<String> searchNames;
  final String phoneLast4;

  Map<String, Object?> toPromptMap() => {
        'display_name': displayName,
        if (searchNames.isNotEmpty) 'aliases': searchNames,
        if (phoneLast4.isNotEmpty) 'phone_last4': phoneLast4,
      };
}

/// Loads device contacts for prompt grounding (wired to ContactDirectory).
typedef ContactCatalogLoader = Future<List<ContactRef>> Function();

/// Supported spatial-agent intents (LLM must emit one of these exactly).
enum AgentIntentType {
  navigate,
  findObject,
  storeMemory,
  teachRoute,
  generalQa,
  emergency,
  callContact,
  contactNotFound,
  rateLimited,
}

extension AgentIntentTypeJson on AgentIntentType {
  String get wireName => switch (this) {
        AgentIntentType.navigate => 'NAVIGATE',
        AgentIntentType.findObject => 'FIND_OBJECT',
        AgentIntentType.storeMemory => 'STORE_MEMORY',
        AgentIntentType.teachRoute => 'TEACH_ROUTE',
        AgentIntentType.generalQa => 'GENERAL_QA',
        AgentIntentType.emergency => 'EMERGENCY',
        AgentIntentType.callContact => 'CALL_CONTACT',
        AgentIntentType.contactNotFound => 'CONTACT_NOT_FOUND',
        AgentIntentType.rateLimited => 'RATE_LIMITED',
      };

  static AgentIntentType parse(String raw) {
    final key = raw.trim().toUpperCase();
    for (final value in AgentIntentType.values) {
      if (value.wireName == key) {
        return value;
      }
    }
    throw IntentParseException(
      'Unknown intent "$raw". Expected one of: '
      '${AgentIntentType.values.map((e) => e.wireName).join(', ')}',
    );
  }
}

/// One known place/node from the spatial graph (SQLite `nodes` row).
class RoomNodeRef {
  const RoomNodeRef({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final String type;

  Map<String, String> toPromptMap() => {
        'id': id,
        'label': label,
        'type': type,
      };
}

/// Loads current room nodes for prompt grounding (wired to SpatialDb in Step 3).
typedef RoomNodeCatalogLoader = Future<List<RoomNodeRef>> Function();

/// Structured intent returned by Gemini Flash (JSON mode).
class AgentIntent {
  const AgentIntent({
    required this.type,
    required this.rawSpeech,
    required this.confidence,
    this.target = '',
    this.nodeId = '',
    this.objectLabel = '',
    this.memoryText = '',
    this.spokenHint = '',
    this.setPlaceThenTeach = false,
  });

  final AgentIntentType type;
  final String rawSpeech;
  final double confidence;
  final String target;
  final String nodeId;
  final String objectLabel;
  final String memoryText;
  final String spokenHint;

  /// Compound: "I am at my couch follow me" → set place, then start teaching.
  final bool setPlaceThenTeach;

  factory AgentIntent.rateLimited(String rawSpeech) => AgentIntent(
        type: AgentIntentType.rateLimited,
        rawSpeech: rawSpeech,
        confidence: 1.0,
        spokenHint:
            'API quota limit reached. Please try again in a moment.',
      );

  factory AgentIntent.fromJson(
    Map<String, dynamic> json, {
    required String rawSpeech,
  }) {
    final typeRaw = json['intent'];
    if (typeRaw is! String || typeRaw.trim().isEmpty) {
      throw IntentParseException(
        'JSON missing required string field "intent".',
      );
    }
    final confidenceRaw = json['confidence'];
    final confidence = switch (confidenceRaw) {
      num n => n.toDouble(),
      _ => throw IntentParseException(
          'JSON missing required numeric field "confidence".',
        ),
    };
    if (confidence < 0 || confidence > 1) {
      throw IntentParseException(
        'confidence must be between 0 and 1 inclusive (got $confidence).',
      );
    }

    String readOptionalString(String key) {
      final value = json[key];
      if (value == null) {
        return '';
      }
      if (value is! String) {
        throw IntentParseException('Field "$key" must be a string or null.');
      }
      return value.trim();
    }

    bool readOptionalBool(String key) {
      final value = json[key];
      if (value == null) {
        return false;
      }
      if (value is bool) {
        return value;
      }
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }

    return AgentIntent(
      type: AgentIntentTypeJson.parse(typeRaw),
      rawSpeech: rawSpeech,
      confidence: confidence,
      target: readOptionalString('target'),
      nodeId: readOptionalString('node_id'),
      objectLabel: readOptionalString('object_label'),
      memoryText: readOptionalString('memory_text'),
      spokenHint: readOptionalString('spoken_hint'),
      setPlaceThenTeach: readOptionalBool('set_place_then_teach'),
    );
  }
}

/// Base error for on-device intent resolution.
class IntentServiceException implements Exception {
  const IntentServiceException(this.message, {this.code = 'INTENT_ERROR'});

  final String message;
  final String code;

  @override
  String toString() => 'IntentServiceException($code): $message';
}

class IntentConfigException extends IntentServiceException {
  const IntentConfigException(super.message)
      : super(code: 'INTENT_CONFIG');
}

class IntentNetworkException extends IntentServiceException {
  const IntentNetworkException(super.message)
      : super(code: 'INTENT_NETWORK');
}

class IntentParseException extends IntentServiceException {
  const IntentParseException(super.message)
      : super(code: 'INTENT_PARSE');
}

class IntentEmptyResponseException extends IntentServiceException {
  const IntentEmptyResponseException(super.message)
      : super(code: 'INTENT_EMPTY');
}

class IntentUpstreamException extends IntentServiceException {
  const IntentUpstreamException(super.message)
      : super(code: 'INTENT_UPSTREAM');
}

class IntentRateLimitedException extends IntentServiceException {
  const IntentRateLimitedException(super.message)
      : super(code: 'INTENT_RATE_LIMITED');
}

/// On-device Gemini Flash intent engine (strict JSON). No regex / keyword matching.
class IntentService {
  IntentService({
    required RoomNodeCatalogLoader loadRoomNodes,
    ContactCatalogLoader? loadContacts,
    String? apiKey,
    String? modelName,
    GenerativeModel? model,
    List<String>? modelFallbackCascade,
  })  : _loadRoomNodes = loadRoomNodes,
        _loadContacts = loadContacts ?? (() async => const []),
        _apiKey = apiKey ?? AppConfig.geminiApiKey,
        _modelName = modelName ?? AppConfig.geminiModel,
        _injectedModel = model,
        _modelFallbackCascade = modelFallbackCascade;

  final RoomNodeCatalogLoader _loadRoomNodes;
  final ContactCatalogLoader _loadContacts;
  final String _apiKey;
  final String _modelName;
  final GenerativeModel? _injectedModel;
  final List<String>? _modelFallbackCascade;
  final Map<String, GenerativeModel> _modelsByName = {};

  static const _defaultFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];

  static const _intentEnumValues = [
    'NAVIGATE',
    'FIND_OBJECT',
    'STORE_MEMORY',
    'TEACH_ROUTE',
    'GENERAL_QA',
    'EMERGENCY',
    'CALL_CONTACT',
    'CONTACT_NOT_FOUND',
    'RATE_LIMITED',
  ];

  static final Schema _responseSchema = Schema.object(
    properties: {
      'intent': Schema.enumString(
        enumValues: _intentEnumValues,
        description: 'Primary user intent class.',
        nullable: false,
      ),
      'confidence': Schema.number(
        description: 'Model confidence from 0.0 to 1.0.',
        nullable: false,
      ),
      'target': Schema.string(
        description:
            'Free-form destination or object phrase from speech (may be empty).',
        nullable: true,
      ),
      'node_id': Schema.string(
        description:
            'Matched spatial node id from the provided room catalog, or empty.',
        nullable: true,
      ),
      'object_label': Schema.string(
        description: 'Canonical object label when intent is FIND_OBJECT.',
        nullable: true,
      ),
      'memory_text': Schema.string(
        description: 'Fact to store when intent is STORE_MEMORY.',
        nullable: true,
      ),
      'spoken_hint': Schema.string(
        description: 'Optional short phrase the app may speak next.',
        nullable: true,
      ),
      'set_place_then_teach': Schema.boolean(
        description:
            'True when speech both sets the current place and starts Follow Me '
            'teaching in one turn (e.g. "I am at my couch follow me").',
        nullable: true,
      ),
    },
    requiredProperties: const ['intent', 'confidence'],
  );

  void _ensureConfigured() {
    if (_apiKey.isEmpty || _apiKey.contains('YOUR_')) {
      throw const IntentConfigException(
        'GEMINI_API_KEY is missing or placeholder in flutter/.env. '
        'Add a real key before calling IntentService.parseSpeech.',
      );
    }
  }

  /// Primary model from env, then Flash fallbacks for 429 / upstream errors.
  List<String> get modelCandidates {
    final custom = _modelFallbackCascade;
    if (custom != null && custom.isNotEmpty) {
      return [
        for (final m in custom)
          if (m.trim().isNotEmpty) m.trim(),
      ];
    }
    final primary = _modelName.trim().isEmpty
        ? 'gemini-2.5-flash'
        : _modelName.trim();
    final out = <String>[primary];
    for (final f in _defaultFallbacks) {
      if (!out.contains(f)) {
        out.add(f);
      }
    }
    return out;
  }

  GenerativeModel _modelFor(String name) {
    _ensureConfigured();
    return _modelsByName.putIfAbsent(
      name,
      () => GenerativeModel(
        model: name,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 512,
          responseMimeType: 'application/json',
          responseSchema: _responseSchema,
        ),
      ),
    );
  }

  static bool isRateLimitError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('rate') ||
        text.contains('quota') ||
        text.contains('resource_exhausted') ||
        text.contains('resource exhausted') ||
        text.contains('too many requests');
  }

  /// Parses [rawSpeech] into a structured [AgentIntent] via Gemini JSON mode.
  ///
  /// Tries [modelCandidates] in order on API / rate-limit errors. If every
  /// candidate is rate-limited, returns [AgentIntent.rateLimited].
  Future<AgentIntent> parseSpeech(String rawSpeech) async {
    final spoken = rawSpeech.trim();
    if (spoken.isEmpty) {
      throw const IntentParseException(
        'Cannot parse empty speech. Provide non-empty rawSpeech.',
      );
    }

    List<RoomNodeRef> nodes;
    try {
      nodes = await _loadRoomNodes();
    } on IntentServiceException {
      rethrow;
    } catch (error, stack) {
      throw IntentUpstreamException(
        'Room node catalog loader failed: $error\n$stack',
      );
    }

    List<ContactRef> contacts;
    try {
      contacts = await _loadContacts();
    } catch (error, stack) {
      throw IntentUpstreamException(
        'Contact catalog loader failed: $error\n$stack',
      );
    }

    final system = _systemInstruction(nodes, contacts);
    final prompt = Content.multi([
      TextPart(system),
      TextPart('User speech:\n$spoken'),
    ]);

    final injected = _injectedModel;
    if (injected != null) {
      return _parseWithModel(injected, prompt, spoken);
    }

    var sawOnlyRateLimits = true;
    Object? lastError;
    for (final name in modelCandidates) {
      try {
        final model = _modelFor(name);
        return await _parseWithModel(model, prompt, spoken);
      } on IntentServiceException catch (error) {
        lastError = error;
        if (!isRateLimitError(error)) {
          sawOnlyRateLimits = false;
        }
        if (isRateLimitError(error) || error is IntentUpstreamException) {
          continue;
        }
        rethrow;
      } catch (error) {
        lastError = error;
        if (!isRateLimitError(error)) {
          sawOnlyRateLimits = false;
        }
        continue;
      }
    }

    if (sawOnlyRateLimits) {
      return AgentIntent.rateLimited(spoken);
    }
    throw IntentUpstreamException(
      'All Gemini models failed while parsing intent. Last error: $lastError',
    );
  }

  Future<AgentIntent> _parseWithModel(
    GenerativeModel model,
    Content prompt,
    String spoken,
  ) async {
    final GenerateContentResponse response;
    try {
      response = await model.generateContent([prompt]);
    } on GenerativeAIException catch (error) {
      final text = error.message;
      if (isRateLimitError(error)) {
        throw IntentRateLimitedException(
          'Gemini rate-limited while parsing intent: $text',
        );
      }
      if (text.toLowerCase().contains('network') ||
          text.toLowerCase().contains('socket') ||
          text.toLowerCase().contains('failed host')) {
        throw IntentNetworkException(
          'Gemini network failure while parsing intent: $text',
        );
      }
      throw IntentUpstreamException(
        'Gemini rejected intent request: $text',
      );
    } catch (error, stack) {
      if (isRateLimitError(error)) {
        throw IntentRateLimitedException(
          'Gemini rate-limited while parsing intent: $error',
        );
      }
      throw IntentUpstreamException(
        'Unexpected Gemini failure while parsing intent: $error\n$stack',
      );
    }

    final body = response.text?.trim() ?? '';
    if (body.isEmpty) {
      final finish = response.candidates.isEmpty
          ? 'no-candidates'
          : response.candidates.first.finishReason?.name ?? 'unknown';
      throw IntentEmptyResponseException(
        'Gemini returned empty JSON for intent parse (finish=$finish).',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw IntentParseException(
        'Gemini returned non-JSON body: ${error.message}. Body=$body',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw IntentParseException(
        'Gemini JSON root must be an object. Got: ${decoded.runtimeType}',
      );
    }

    final intent = AgentIntent.fromJson(decoded, rawSpeech: spoken);
    if (intent.type == AgentIntentType.rateLimited) {
      return AgentIntent.rateLimited(spoken);
    }
    return intent;
  }

  String _systemInstruction(List<RoomNodeRef> nodes, List<ContactRef> contacts) {
    final catalog = nodes.isEmpty
        ? '[]'
        : jsonEncode(nodes.map((n) => n.toPromptMap()).toList());
    final contactCatalog = contacts.isEmpty
        ? '[]'
        : jsonEncode(contacts.map((c) => c.toPromptMap()).toList());
    return '''
You are the VisionAid++ spatial intent classifier for a blind navigation agent.
Return ONLY JSON matching the response schema. Do not invent node ids or contacts.
Understand English, Hindi, and Hinglish naturally. Do NOT require exact keywords.

Known room nodes (SQLite catalog JSON):
$catalog

Known phone contacts (device address book JSON):
$contactCatalog

Intent meanings:
- NAVIGATE: user wants to go to a place/node (set node_id when catalog match is clear; else target).
- FIND_OBJECT: user wants to locate an object — including "find laptop", "find my laptop", "laptop kahan hai", "where is my bottle" (set object_label).
- STORE_MEMORY: user asks to remember a fact or place association (set memory_text). For "I am at my couch" set target/node to the place.
- TEACH_ROUTE: user wants Follow Me path teaching. For compound "I am at my couch follow me" set intent TEACH_ROUTE, target/node_id to the place, and set_place_then_teach=true.
- GENERAL_QA: conversational question that is not navigation/find/memory/route/emergency/call.
- EMERGENCY: urgent help, fall, danger, call emergency contact.
- CALL_CONTACT: user wants to call someone AND a contact catalog entry clearly matches (set target to that entry's exact display_name).
- CONTACT_NOT_FOUND: user wants to call/message someone but NO catalog entry plausibly matches (set target to spoken name).
- RATE_LIMITED: never emit this yourself; reserved for the app.

Compound Follow Me:
- "I am at my couch follow me" / "main couch pe hoon follow me" → TEACH_ROUTE + set_place_then_teach=true + target/node for couch.
- "Follow me" alone while teaching finishes needs destination in target.
- "Follow me to kitchen" → TEACH_ROUTE with destination kitchen (finish if teaching active).

Contact resolution rules (critical):
- Match call/message requests ONLY against the contact catalog above.
- Relationship words (mummy, mom, mother, मम्मी, papa, dad) must map ONLY to contacts whose display_name or aliases clearly are that relationship — never substring guesses like ma→Mama.
- NEVER return CALL_CONTACT with an unrelated name.
- If the catalog is empty or no entry fits, return CONTACT_NOT_FOUND (not CALL_CONTACT).
- When matched, target MUST be the exact display_name string from the matched catalog entry.

Map natural place phrases to node_id using label/type similarity from the room catalog only.
If no room catalog entry fits, leave node_id empty and put the phrase in target.
''';
  }
}

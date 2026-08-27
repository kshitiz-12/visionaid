import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../../features/context_engine/domain/services/context_engine.dart';
import '../../features/emergency/data/emergency_service.dart';
import '../../features/intent/domain/entities/user_intent.dart';
import '../../features/intent/domain/services/intent_engine.dart';
import '../../features/ocr/domain/services/ocr_engine.dart';
import '../../features/vision/data/services/scene_labeler.dart';
import '../../features/vision/domain/services/object_detector_service.dart';
import '../exceptions/app_exception.dart';
import '../network/companion_client.dart';
import 'camera_capture_service.dart';
import 'conversation_memory.dart';
import 'pipeline_result.dart';
import 'scene_policy.dart';
import 'user_prefs.dart';

/// Intent → local actions (call / emergency / OCR / vision) or cloud companion.
class AssistantPipeline {
  AssistantPipeline({
    required this.intentEngine,
    required this.camera,
    required this.detector,
    required this.ocr,
    required this.contextEngine,
    required this.emergency,
    required this.companion,
    required this.memory,
    required this.labeler,
  });

  final IntentEngine intentEngine;
  final CameraCaptureService camera;
  final ObjectDetectorService detector;
  final OcrEngine ocr;
  final ContextEngine contextEngine;
  final EmergencyService emergency;
  final CompanionClient companion;
  final ConversationMemory memory;
  final SceneLabeler labeler;

  Future<PipelineResult> handleSpoken(
    String spokenText, {
    void Function(String sentence)? onSentence,
  }) async {
    final intent = await intentEngine.classify(spokenText);

    if (ScenePolicy.wantsRepeat(spokenText) && memory.lastReply.isNotEmpty) {
      return PipelineResult(
        intent: intent,
        spokenReply: memory.lastReply,
      );
    }

    if (!intent.isActionable || intent.type == IntentType.cancel) {
      if (intent.rawText.trim().isEmpty) {
        return PipelineResult(
          intent: intent,
          spokenReply: "I didn't catch that. Please try again.",
        );
      }
      return PipelineResult(
        intent: intent,
        spokenReply: 'Okay, cancelled.',
      );
    }

    switch (intent.type) {
      case IntentType.help:
      case IntentType.conversation:
      case IntentType.unknown:
        return _chat(intent, onSentence: onSentence);
      case IntentType.emergency:
        final callMsg = await emergency.placeCall(
          contactName: intent.contactName,
        );
        return PipelineResult(
          intent: intent,
          spokenReply: 'Emergency. $callMsg',
          isAlert: true,
        );
      case IntentType.communication:
        if (intent.commAction == CommAction.sms) {
          if (intent.messageBody.isEmpty) {
            return PipelineResult(
              intent: intent,
              spokenReply: intent.contactName.isEmpty
                  ? 'Who should I text?'
                  : 'What should I say to ${intent.contactName}?',
            );
          }
          final smsMsg = await emergency.sendSms(
            contactName: intent.contactName,
            message: intent.messageBody,
          );
          return PipelineResult(intent: intent, spokenReply: smsMsg);
        }
        if (intent.commAction == CommAction.whatsapp) {
          if (intent.messageBody.isEmpty) {
            return PipelineResult(
              intent: intent,
              spokenReply: intent.contactName.isEmpty
                  ? 'Who should I WhatsApp?'
                  : 'What should I say to ${intent.contactName} on WhatsApp?',
            );
          }
          final wa = await emergency.sendWhatsApp(
            contactName: intent.contactName,
            message: intent.messageBody,
          );
          return PipelineResult(intent: intent, spokenReply: wa);
        }
        if (intent.contactName.isEmpty) {
          return PipelineResult(
            intent: intent,
            spokenReply: 'Who should I call?',
          );
        }
        final callMsg = await emergency.placeCall(
          contactName: intent.contactName,
        );
        return PipelineResult(intent: intent, spokenReply: callMsg);
      case IntentType.quit:
        return PipelineResult(
          intent: intent,
          spokenReply: 'Closing VisionAid. Goodbye.',
        );
      case IntentType.readText:
        return _runOcr(intent, onSentence: onSentence);
      case IntentType.navigation:
      case IntentType.findObject:
      case IntentType.sceneDescribe:
        return _runVisionThenChat(intent, onSentence: onSentence);
      case IntentType.routeNavigate:
        return PipelineResult(
          intent: intent,
          spokenReply: intent.target.isEmpty
              ? 'Where should I take you?'
              : 'Opening outdoor route to ${intent.target}.',
        );
      case IntentType.cancel:
        return PipelineResult(intent: intent, spokenReply: 'Okay, cancelled.');
    }
  }

  Future<({String facts, String imageBase64})> _captureScene(UserIntent intent) async {
    try {
      final shot = await camera.captureJpeg();
      final detections = await detector.detect(shot.path);
      final named = detections
          .where(
            (d) =>
                d.label.isNotEmpty &&
                d.label != 'obstacle' &&
                d.label != 'object',
          )
          .length;
      List<RawDetection> labels = const [];
      // YOLO already names COCO classes — skip slow Image Labeler when confident.
      if (named < 2) {
        try {
          labels = await labeler.label(InputImage.fromFilePath(shot.path));
        } catch (_) {}
      }
      final merged = SceneLabeler.merge(detections, labels);
      final maps = merged.map((d) => d.toMap()).toList();
      final decision = contextEngine.evaluate(
        detections: maps,
        intentTarget: intent.target,
      );
      final bits = <String>[];
      for (final d in merged.take(5)) {
        if (d.label.isEmpty) {
          continue;
        }
        bits.add('${d.label} ${_sideOf(d)}');
      }
      var facts = bits.isEmpty
          ? 'On-device did not name anything. Trust the photo.'
          : 'On-device names: ${bits.join('; ')}. Trust the photo more.';
      if (decision.reason == 'hazard') {
        facts = '${decision.spokenMessage} $facts';
      }
      memory.rememberScene(facts);
      return (facts: facts, imageBase64: shot.imageBase64);
    } catch (_) {
      return (facts: memory.lastScene, imageBase64: '');
    }
  }

  String _sideOf(RawDetection d) {
    if (d.frameWidth <= 0 || d.boxWidth <= 0) {
      return 'ahead';
    }
    final cx = (d.boxLeft + d.boxWidth / 2) / d.frameWidth;
    if (cx < 0.38) {
      return 'left';
    }
    if (cx > 0.62) {
      return 'right';
    }
    return 'ahead';
  }

  bool _needsFreshScene(UserIntent intent) => ScenePolicy.wantsCamera(intent);

  Future<PipelineResult> _chat(
    UserIntent intent, {
    void Function(String sentence)? onSentence,
  }) async {
    var scene = '';
    var imageBase64 = '';
    if (_needsFreshScene(intent)) {
      final snap = await _captureScene(intent);
      scene = snap.facts;
      imageBase64 = snap.imageBase64;
    } else if (ScenePolicy.wantsRepeat(intent.rawText)) {
      scene = memory.lastScene;
    }

    final languageCode = await UserPrefs.getLanguageCode();
    final language = AppLanguage.fromCode(languageCode);
    final name = await UserPrefs.getName();

    try {
      final reply = await companion.chatStream(
        message: intent.rawText,
        language: language.code,
        userName: name,
        sceneSummary: scene,
        history: memory.history
            .where(
              (turn) =>
                  !(turn['content'] ?? '').toLowerCase().startsWith('stop.'),
            )
            .toList(),
        imageBase64: imageBase64,
        onSentence: onSentence,
      );
      memory.addTurn(user: intent.rawText, assistant: reply.text);
      return PipelineResult(intent: intent, spokenReply: reply.text);
    } on AppException catch (error) {
      if (error.code == 'AI_NOT_CONFIGURED' ||
          error.code == 'NETWORK_ERROR' ||
          error.code == 'AI_UPSTREAM' ||
          error.code == 'AI_EMPTY') {
        return PipelineResult(
          intent: intent,
          spokenReply: language.code == 'hi'
              ? 'इंटरनेट सहायक अभी नहीं जवाब दे पाया। कॉल, इमरजेंसी और गाइड अभी भी चलेंगे। ${_offlineVisionHint(scene, language.code)}'
              : '${_offlineVisionHint(scene, language.code)} Call, emergency, and look ahead still work.',
        );
      }
      return PipelineResult(
        intent: intent,
        spokenReply: error.message,
        isAlert: true,
      );
    } catch (error) {
      return PipelineResult(
        intent: intent,
        spokenReply: _friendlyError(error),
        isAlert: true,
      );
    }
  }

  Future<PipelineResult> _runVisionThenChat(
    UserIntent intent, {
    void Function(String sentence)? onSentence,
  }) async {
    return _chat(intent, onSentence: onSentence);
  }

  Future<PipelineResult> _runOcr(
    UserIntent intent, {
    void Function(String sentence)? onSentence,
  }) async {
    try {
      final shot = await camera.captureJpeg();
      final text = await ocr.recognizeText(shot.path);
      final clipped = text.length > 400 ? '${text.substring(0, 400)}…' : text;
      if (clipped.isNotEmpty) {
        memory.rememberScene('Printed text: $clipped');
      }
      final language = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
      try {
        final reply = await companion.chatStream(
          message: clipped.isEmpty
              ? 'Look at this photo. Read any text or money you can see, in a natural spoken way.'
              : 'Read any print in the photo naturally, including money amounts if a note is visible. OCR hint: $clipped',
          language: language.code,
          userName: await UserPrefs.getName(),
          sceneSummary: memory.lastScene,
          history: memory.history,
          imageBase64: shot.imageBase64,
          onSentence: onSentence,
        );
        memory.addTurn(user: intent.rawText, assistant: reply.text);
        return PipelineResult(intent: intent, spokenReply: reply.text);
      } catch (_) {
        return PipelineResult(
          intent: intent,
          spokenReply: clipped.isEmpty
              ? 'I could not read the print. Hold the phone steady.'
              : 'It says: $clipped',
        );
      }
    } catch (error) {
      return PipelineResult(
        intent: intent,
        spokenReply: _friendlyError(error),
        isAlert: true,
      );
    }
  }

  String _offlineVisionHint(String scene, String lang) {
    final facts = scene.trim();
    final has = facts.isNotEmpty &&
        !facts.toLowerCase().contains('detected: none') &&
        facts.toLowerCase() != 'none';
    if (lang == 'hi') {
      return has ? 'कैमरा दिखाता है: $facts' : 'कैमरा दृश्य अभी खाली है।';
    }
    return has
        ? 'From the camera: $facts'
        : 'I could not reach the internet assistant just now.';
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Bad state: ', '');
    if (raw.toLowerCase().contains('camera') ||
        raw.toLowerCase().contains('permission')) {
      return raw;
    }
    return 'Something went wrong. $raw';
  }

  Future<void> dispose() async {
    await detector.dispose();
    await ocr.dispose();
  }
}

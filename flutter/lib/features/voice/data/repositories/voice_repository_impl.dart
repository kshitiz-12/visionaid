import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_context.dart';
import '../../domain/repositories/voice_repository.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  @override
  Future<VoiceCommand> classifyCommand(String spokenText) async {
    final normalized = spokenText.trim();
    if (normalized.isEmpty) {
      throw StateError('Spoken text cannot be empty');
    }

    final lower = normalized.toLowerCase();
    String intent = 'general';
    bool actionable = true;
    double confidence = 0.72;

    if (lower.contains('emergency') || lower.contains('help') || lower.contains('danger')) {
      intent = 'emergency';
      confidence = 0.97;
    } else if (lower.contains('navigate') || lower.contains('go to') || lower.contains('find route')) {
      intent = 'navigation';
      confidence = 0.9;
    } else if (lower.contains('read') || lower.contains('what does it say') || lower.contains('read text')) {
      intent = 'read_text';
      confidence = 0.88;
    } else if (lower.contains('where is') || lower.contains('find')) {
      intent = 'find_object';
      confidence = 0.84;
    }

    if (lower.contains('stop') || lower.contains('cancel')) {
      actionable = false;
      confidence = 0.65;
    }

    return VoiceCommand(
      rawText: normalized,
      intent: intent,
      confidence: confidence,
      isActionable: actionable,
    );
  }

  @override
  Future<VoiceContext> buildContext({required String spokenText}) async {
    final lower = spokenText.trim().toLowerCase();

    String intent = 'general';
    if (lower.contains('navigate')) {
      intent = 'navigation';
    } else if (lower.contains('read')) {
      intent = 'read_text';
    } else if (lower.contains('emergency') || lower.contains('danger')) {
      intent = 'emergency';
    } else if (lower.contains('where is') || lower.contains('find')) {
      intent = 'find_object';
    }

    final urgency = intent == 'emergency'
        ? 'high'
        : (intent == 'navigation' || intent == 'read_text' ? 'medium' : 'low');

    String target = 'environment';
    if (lower.contains('sign')) {
      target = 'sign';
    } else if (lower.contains('door')) {
      target = 'door';
    } else if (lower.contains('exit')) {
      target = 'exit';
    } else if (lower.contains('car')) {
      target = 'vehicle';
    }

    return VoiceContext(
      intent: intent,
      location: lower.contains('outside') ? 'outdoor' : 'indoor',
      userMood: lower.contains('panic') || lower.contains('danger') ? 'alert' : 'focused',
      environment: lower.contains('outside') ? 'outdoor' : 'indoor',
      urgency: urgency,
      target: target,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/voice/data/repositories/voice_repository_impl.dart';

void main() {
  group('voice repository', () {
    final repository = VoiceRepositoryImpl();

    test('detects emergencies and keeps them actionable', () async {
      final command = await repository.classifyCommand('Emergency, a car is heading toward me');

      expect(command.intent, 'emergency');
      expect(command.isActionable, isTrue);
      expect(command.confidence, greaterThan(0.8));
    });

    test('maps navigation and read requests to relevant context', () async {
      final command = await repository.classifyCommand('Read the sign above the door');
      final context = await repository.buildContext(spokenText: 'Read the sign above the door');

      expect(command.intent, 'read_text');
      expect(context.intent, 'read_text');
      expect(context.urgency, 'medium');
      expect(context.target, 'sign');
    });
  });
}

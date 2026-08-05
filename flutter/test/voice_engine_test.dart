import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/stt_service.dart';
import 'package:visionaid/core/services/tts_service.dart';
import 'package:visionaid/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:visionaid/features/voice/domain/services/voice_engine.dart';

void main() {
  group('voice engine', () {
    test('listens, classifies, and speaks the response', () async {
      final engine = VoiceEngine(
        repository: VoiceRepositoryImpl(),
        speechToTextService: MockSpeechToTextService(),
        textToSpeechService: MockTextToSpeechService(),
      );

      final heard = await engine.listen();
      final command = await engine.processSpokenText(heard);
      await engine.speak('Emergency detected. Please keep moving to safety.');

      expect(heard, isNotEmpty);
      expect(command.intent, 'emergency');
      expect(command.isActionable, isTrue);
    });
  });
}

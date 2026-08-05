import '../../../../core/services/stt_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/repositories/voice_repository_impl.dart';
import '../entities/voice_command.dart';

class VoiceEngine {
  VoiceEngine({
    required this.repository,
    required this.speechToTextService,
    required this.textToSpeechService,
  });

  final VoiceRepositoryImpl repository;
  final SpeechToTextService speechToTextService;
  final TextToSpeechService textToSpeechService;

  Future<String> listen() async {
    return speechToTextService.listen();
  }

  Future<VoiceCommand> processSpokenText(String spokenText) async {
    return repository.classifyCommand(spokenText);
  }

  Future<void> speak(String text) async {
    await textToSpeechService.speak(text);
  }
}

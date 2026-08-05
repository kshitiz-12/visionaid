import '../entities/voice_command.dart';
import '../entities/voice_context.dart';

abstract class VoiceRepository {
  Future<VoiceCommand> classifyCommand(String spokenText);
  Future<VoiceContext> buildContext({required String spokenText});
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_context.dart';
import '../../data/repositories/voice_repository_impl.dart';

final voiceRepositoryProvider = Provider<VoiceRepositoryImpl>((ref) {
  return VoiceRepositoryImpl();
});

final voiceCommandProvider = StateNotifierProvider<VoiceCommandController, VoiceCommand?>(
  (ref) => VoiceCommandController(ref.watch(voiceRepositoryProvider)),
);

final voiceContextProvider = StateNotifierProvider<VoiceContextController, VoiceContext?>(
  (ref) => VoiceContextController(ref.watch(voiceRepositoryProvider)),
);

class VoiceCommandController extends StateNotifier<VoiceCommand?> {
  VoiceCommandController(this._repository) : super(null);

  final VoiceRepositoryImpl _repository;

  Future<void> parse(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      state = null;
      return;
    }

    state = await _repository.classifyCommand(spokenText);
  }
}

class VoiceContextController extends StateNotifier<VoiceContext?> {
  VoiceContextController(this._repository) : super(null);

  final VoiceRepositoryImpl _repository;

  Future<void> buildContext(String spokenText) async {
    state = await _repository.buildContext(spokenText: spokenText);
  }
}

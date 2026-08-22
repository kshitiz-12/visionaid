import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../services/stt_service.dart';
import '../services/tts_service.dart';

final textToSpeechProvider = Provider<TextToSpeechService>((ref) {
  return HumanizedTextToSpeechService();
});

final speechToTextProvider = Provider<SpeechToTextService>((ref) {
  return AndroidSpeechToTextService();
});

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

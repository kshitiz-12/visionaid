import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/context_engine/data/context_engine_impl.dart';
import '../../features/context_engine/domain/services/context_engine.dart';
import '../../features/emergency/data/emergency_service.dart';
import '../../features/intent/data/intent_engine_impl.dart';
import '../../features/intent/domain/services/intent_engine.dart';
import '../../features/ocr/data/mlkit_ocr_engine.dart';
import '../../features/ocr/domain/services/ocr_engine.dart';
import '../../features/vision/data/services/mlkit_object_detector.dart';
import '../../features/vision/data/services/scene_labeler.dart';
import '../../features/vision/domain/services/object_detector_service.dart';
import '../network/companion_client.dart';
import '../services/assistant_pipeline.dart';
import '../services/camera_capture_service.dart';
import '../services/conversation_memory.dart';

final intentEngineProvider = Provider<IntentEngine>((ref) {
  return IntentEngineImpl();
});

final contextEngineProvider = Provider<ContextEngine>((ref) {
  return ContextEngineImpl();
});

final cameraCaptureProvider = Provider<CameraCaptureService>((ref) {
  return CameraCaptureService();
});

final objectDetectorProvider = Provider<ObjectDetectorService>((ref) {
  final detector = MlKitObjectDetector(stream: true);
  ref.onDispose(detector.dispose);
  return detector;
});

final sceneLabelerProvider = Provider<SceneLabeler>((ref) {
  final labeler = SceneLabeler();
  ref.onDispose(labeler.dispose);
  return labeler;
});

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final companionClientProvider = Provider<CompanionClient>((ref) {
  return CompanionClient();
});

final conversationMemoryProvider = Provider<ConversationMemory>((ref) {
  return ConversationMemory();
});

final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService();
});

final assistantPipelineProvider = Provider<AssistantPipeline>((ref) {
  final pipeline = AssistantPipeline(
    intentEngine: ref.watch(intentEngineProvider),
    camera: ref.watch(cameraCaptureProvider),
    detector: ref.watch(objectDetectorProvider),
    ocr: ref.watch(ocrEngineProvider),
    contextEngine: ref.watch(contextEngineProvider),
    emergency: ref.watch(emergencyServiceProvider),
    companion: ref.watch(companionClientProvider),
    memory: ref.watch(conversationMemoryProvider),
  );
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

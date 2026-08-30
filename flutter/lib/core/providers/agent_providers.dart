import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/communication/data/contact_directory.dart';
import '../config/app_config.dart';
import '../../services/active_node_store.dart';
import '../../services/app_mode_controller.dart';
import '../../services/imu_tracker.dart';
import '../../services/intent_service.dart';
import '../../services/memory_tracker.dart';
import '../../services/priority_audio.dart';
import '../../services/spatial_db.dart';
import '../../services/spatial_fusion.dart';
import 'voice_providers.dart';

final activeNodeStoreProvider = Provider<ActiveNodeStore>((ref) {
  return ActiveNodeStore();
});

final appModeControllerProvider = Provider<AppModeController>((ref) {
  return AppModeController();
});

final spatialDbProvider = Provider<SpatialDb>((ref) {
  final db = SpatialDb();
  ref.onDispose(() {
    // ignore: discarded_futures
    db.close();
  });
  return db;
});

/// Ensures [SpatialDb] is open and [ActiveNodeStore] is loaded once.
final spatialAgentReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(spatialDbProvider);
  final nodes = ref.watch(activeNodeStoreProvider);
  await db.open();
  await nodes.load();
});

final intentServiceProvider = Provider<IntentService>((ref) {
  final db = ref.watch(spatialDbProvider);
  final contacts = ContactDirectory();
  return IntentService(
    loadRoomNodes: () async {
      if (!db.isOpen) {
        await db.open();
      }
      return db.loadRoomNodes();
    },
    loadContacts: contacts.loadPromptCatalog,
    apiKey: AppConfig.geminiApiKey,
    modelName: AppConfig.geminiModel,
  );
});

final memoryTrackerProvider = Provider<MemoryTracker>((ref) {
  return MemoryTracker(
    spatialDb: ref.watch(spatialDbProvider),
    minConfidence: 0.45,
    minLogInterval: const Duration(seconds: 4),
    persistenceWindow: 5,
    persistenceHitsRequired: 3,
  );
});

final spatialFusionProvider = Provider<SpatialFusion>((ref) {
  return SpatialFusion(
    calibration: DepthMetricCalibration.visionAidMidasSmall,
  );
});

final priorityAudioProvider = Provider<PriorityAudio>((ref) {
  final audio = PriorityAudio(tts: ref.watch(textToSpeechProvider));
  ref.onDispose(() {
    // ignore: discarded_futures
    audio.dispose();
  });
  return audio;
});

final imuTrackerProvider = Provider<ImuTracker>((ref) {
  final tracker = ImuTracker(spatialDb: ref.watch(spatialDbProvider));
  ref.onDispose(() {
    // ignore: discarded_futures
    tracker.dispose();
  });
  return tracker;
});

import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/services/app_mode_controller.dart';
import 'package:visionaid/services/memory_tracker.dart';

void main() {
  group('AppModeController', () {
    test('target search mutes path clear and ambient scene', () {
      final modes = AppModeController();
      expect(modes.allowPathClearSpeech, isTrue);
      modes.enterTargetSearch('shoes');
      expect(modes.isTargetSearch, isTrue);
      expect(modes.searchTarget, 'shoes');
      expect(modes.allowPathClearSpeech, isFalse);
      expect(modes.allowAmbientSceneSpeech, isFalse);
      expect(
        modes.allowHazardInterrupt(depthMetres: 1.0, safetyCritical: true),
        isFalse,
      );
      expect(
        modes.allowHazardInterrupt(depthMetres: 0.3, safetyCritical: true),
        isTrue,
      );
      modes.enterHazardNavigation();
      expect(modes.isHazardNavigation, isTrue);
      expect(modes.allowPathClearSpeech, isTrue);
    });
  });

  group('MemoryTracker taxonomy', () {
    test('shoes synonyms match footwear and sneakers', () {
      expect(MemoryTracker.semanticMatch('shoe', 'shoes'), 1.0);
      expect(MemoryTracker.semanticMatch('footwear', 'my shoes'), greaterThan(0.8));
      expect(MemoryTracker.semanticMatch('sneaker', 'shoes'), 1.0);
      expect(MemoryTracker.canonicalStorageLabel('footwear'), 'shoes');
    });

    test('laptop synonyms include computer and notebook', () {
      expect(MemoryTracker.semanticMatch('computer', 'laptop'), 1.0);
      expect(
        MemoryTracker.expandSynonymQueries('find my laptop'),
        isNotEmpty,
      );
      expect(
        MemoryTracker.expandSynonymQueries('laptop'),
        contains('computer'),
      );
    });

    test('material tags are ambient noise', () {
      expect(MemoryTracker.isAmbientNoise('metal'), isTrue);
      expect(MemoryTracker.isAmbientNoise('plastic'), isTrue);
      expect(MemoryTracker.isAmbientNoise('shoes'), isFalse);
      expect(MemoryTracker.isAmbientNoise('laptop'), isFalse);
    });
  });
}

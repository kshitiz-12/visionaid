import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/vision/data/repositories/vision_repository_impl.dart';
import 'package:visionaid/features/vision/domain/services/vision_engine.dart';

void main() {
  group('vision engine', () {
    test('ranks hazards above low-priority objects', () async {
      final repository = VisionRepositoryImpl();
      final engine = VisionEngine(repository: repository);

      final objects = await engine.analyzeFrame(detections: [
        {
          'label': 'vehicle',
          'confidence': 0.92,
          'distance': 0.4,
          'isMoving': true,
          'importance': 0.9,
          'navigationRisk': 0.85,
        },
        {
          'label': 'tree',
          'confidence': 0.7,
          'distance': 0.7,
          'isMoving': false,
          'importance': 0.5,
          'navigationRisk': 0.3,
        },
      ]);

      expect(objects.first.label, 'vehicle');
      expect(objects.first.isHazard, isTrue);
      expect(engine.summarizePriority(objects), contains('Hazard'));
    });
  });
}

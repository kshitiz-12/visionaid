import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/vision/data/services/scene_labeler.dart';
import 'package:visionaid/features/vision/data/services/scene_vocab.dart';
import 'package:visionaid/features/vision/domain/services/object_detector_service.dart';

void main() {
  test('normalizes common labeler names', () {
    expect(SceneVocab.normalize('Headphones'), 'headphones');
    expect(SceneVocab.normalize('headphones'), isNot('phone'));
    expect(SceneVocab.normalize('laptop computer'), 'laptop');
    expect(SceneVocab.normalize('screenshot'), isEmpty);
  });

  test('merges unlabeled boxes with scene names and keeps proximity', () {
    const boxes = [
      RawDetection(label: 'object', confidence: 0.4, distance: 0.8),
    ];
    const names = [
      RawDetection(label: 'person', confidence: 0.9, distance: 0.5),
    ];
    final merged = SceneLabeler.merge(boxes, names);
    expect(merged, isNotEmpty);
    expect(merged.first.label, 'person');
    expect(merged.first.distance, closeTo(0.8, 0.01));
  });
}

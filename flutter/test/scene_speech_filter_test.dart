import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/vision/data/services/scene_speech_filter.dart';
import 'package:visionaid/features/vision/domain/services/object_detector_service.dart';

void main() {
  test('drops label-only ghosts in hazard navigation', () {
    const ghost = RawDetection(label: 'car', confidence: 0.6, distance: 0.5);
    expect(SceneSpeechFilter.keep(ghost, targetSearch: false), isFalse);

    const real = RawDetection(
      label: 'bottle',
      confidence: 0.62,
      distance: 0.4,
      boxWidth: 0.2,
      boxHeight: 0.3,
    );
    expect(SceneSpeechFilter.keep(real, targetSearch: false), isTrue);
  });

  test('allows label-only in target search', () {
    const labelOnly = RawDetection(label: 'shoes', confidence: 0.55, distance: 0.5);
    expect(SceneSpeechFilter.keep(labelOnly, targetSearch: true), isTrue);
  });

  test('suppresses low-confidence outdoor vehicles indoors', () {
    const car = RawDetection(
      label: 'car',
      confidence: 0.7,
      distance: 0.5,
      boxWidth: 0.3,
      boxHeight: 0.2,
    );
    expect(SceneSpeechFilter.keep(car, targetSearch: false), isFalse);
  });
}

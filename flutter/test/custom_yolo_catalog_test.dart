import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/guide_alerts/data/response_generator.dart';
import 'package:visionaid/features/guide_alerts/domain/guide_models.dart';
import 'package:visionaid/features/vision/data/services/custom_yolo_catalog.dart';
import 'package:visionaid/features/vision/data/services/scene_vocab.dart';

void main() {
  test('custom catalog class order matches names file contract', () {
    expect(CustomYoloCatalog.classes.first, 'stairs');
    expect(CustomYoloCatalog.classes[7], 'door');
    expect(CustomYoloCatalog.classes[13], 'inr_500');
    expect(CustomYoloCatalog.classes.last, 'ointment_tube');
    expect(CustomYoloCatalog.nameOf(0), 'stairs');
    expect(CustomYoloCatalog.nameOf(99), isNull);
    expect(CustomYoloCatalog.isHazard('pothole'), isTrue);
    expect(CustomYoloCatalog.isMoney('inr_500'), isTrue);
  });

  test('scene vocab normalizes custom labels', () {
    expect(SceneVocab.normalize('open_drain'), 'open_drain');
    expect(SceneVocab.normalize('500 rupee'), 'inr_500');
    expect(SceneVocab.normalize('wet floor sign'), 'wet_floor_sign');
    expect(SceneVocab.normalize('blister pack'), 'blister_pack');
  });

  test('speech says rupee notes and ground hazards clearly', () {
    const en = ResponseGenerator();
    const hi = ResponseGenerator(hindi: true);
    final note = GuideObjectSnapshot(
      label: 'inr_500',
      confidence: 0.9,
      boundingBox: (left: 0.4, top: 0.4, right: 0.6, bottom: 0.55),
      direction: GuideDirection.center,
      distanceMeters: 0.8,
    );
    expect(
      en.live(
        snap: note,
        others: const [],
        band: PriorityBand.announce,
        risk: 0.1,
        movement: MovementState.unknown,
      ),
      contains('500 rupee note'),
    );
    expect(
      hi.live(
        snap: note,
        others: const [],
        band: PriorityBand.announce,
        risk: 0.1,
        movement: MovementState.unknown,
      ),
      contains('पाँच सौ रुपये'),
    );

    final drain = GuideObjectSnapshot(
      label: 'open_drain',
      confidence: 0.9,
      boundingBox: (left: 0.35, top: 0.5, right: 0.65, bottom: 0.9),
      direction: GuideDirection.center,
      distanceMeters: 1.0,
    );
    expect(
      en.live(
        snap: drain,
        others: const [],
        band: PriorityBand.critical,
        risk: 0.95,
        movement: MovementState.approaching,
      ),
      startsWith('Stop. open drain'),
    );
  });
}

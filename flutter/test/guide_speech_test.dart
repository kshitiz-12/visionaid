import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/guide_alerts/data/response_generator.dart';
import 'package:visionaid/features/guide_alerts/data/spatial_relations.dart';
import 'package:visionaid/features/guide_alerts/domain/guide_models.dart';
import 'package:visionaid/features/vision/data/services/money_note_reader.dart';

void main() {
  const speech = ResponseGenerator();

  test('door left about a meter, then reached', () {
    expect(
      speech.distancePhrase(0.25),
      'one metre',
    );
    expect(
      speech.targetFound(
        label: 'door',
        direction: GuideDirection.left,
        proximity: 0.25,
      ),
      'Door, left, one metre.',
    );
    expect(
      speech.targetFound(
        label: 'door',
        direction: GuideDirection.center,
        proximity: 0.5,
        reached: true,
      ),
      'Stop. You have reached the door.',
    );
  });

  test('headphones on the table', () {
    final phones = GuideObjectSnapshot(
      label: 'headphones',
      confidence: 0.8,
      boundingBox: (left: 0.4, top: 0.2, right: 0.55, bottom: 0.35),
      direction: GuideDirection.center,
    );
    final table = GuideObjectSnapshot(
      label: 'table',
      confidence: 0.8,
      boundingBox: (left: 0.2, top: 0.32, right: 0.8, bottom: 0.9),
      direction: GuideDirection.center,
    );
    expect(
      SpatialRelations.phrase(phones, [phones, table]),
      'on the table',
    );
  });

  test('reads rupee note amount from print', () {
    expect(
      MoneyNoteReader.speakFromOcr('Reserve Bank of India 500'),
      contains('500 rupees'),
    );
    expect(MoneyNoteReader.looksLikeCash(['cash']), isTrue);
  });

  test('metres stay approximate, never millimetre-precise', () {
    expect(speech.metresOrBoxPhrase(1.037, 0.2), 'one metre');
    expect(speech.metresOrBoxPhrase(null, 0.25), 'one metre');
  });

  test('live lines stay short, no extra objects', () {
    final chair = GuideObjectSnapshot(
      label: 'chair',
      confidence: 0.9,
      boundingBox: (left: 0.4, top: 0.2, right: 0.6, bottom: 0.8),
      direction: GuideDirection.center,
      distanceMeters: 1.1,
    );
    final bottle = GuideObjectSnapshot(
      label: 'bottle',
      confidence: 0.9,
      boundingBox: (left: 0.1, top: 0.4, right: 0.2, bottom: 0.55),
      direction: GuideDirection.left,
      distanceMeters: 1.2,
    );
    expect(
      speech.live(
        snap: chair,
        others: [chair, bottle],
        band: PriorityBand.announce,
        risk: 0.2,
        movement: MovementState.unknown,
      ),
      'Chair, ahead, one metre.',
    );
    expect(speech.extras([chair, bottle], skipLabel: 'chair'), isEmpty);
  });

  test('safety speech keeps approximate distance and object name', () {
    final chair = GuideObjectSnapshot(
      label: 'chair',
      confidence: 0.8,
      boundingBox: (left: 0.4, top: 0.2, right: 0.6, bottom: 0.8),
      direction: GuideDirection.center,
      distanceMeters: 1.1,
      boxProximity: 0.3,
    );
    expect(
      speech.live(
        snap: chair,
        others: [chair],
        band: PriorityBand.announce,
        risk: 0.2,
        movement: MovementState.unknown,
      ),
      contains('one metre'),
    );
    expect(
      speech.live(
        snap: chair,
        others: [chair],
        band: PriorityBand.critical,
        risk: 0.9,
        movement: MovementState.unknown,
        reached: true,
      ),
      contains('Chair'),
    );
    final unnamed = GuideObjectSnapshot(
      label: 'object',
      confidence: 0.8,
      boundingBox: (left: 0.4, top: 0.2, right: 0.6, bottom: 0.8),
      direction: GuideDirection.left,
      distanceMeters: 1.0,
      boxProximity: 0.3,
    );
    expect(
      speech.live(
        snap: unnamed,
        others: [unnamed],
        band: PriorityBand.critical,
        risk: 0.9,
        movement: MovementState.unknown,
      ),
      isNot(contains('Object')),
    );
    expect(
      speech.live(
        snap: unnamed,
        others: [unnamed],
        band: PriorityBand.critical,
        risk: 0.9,
        movement: MovementState.unknown,
      ),
      contains('Tall thing'),
    );
  });
}

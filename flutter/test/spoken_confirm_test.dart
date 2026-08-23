import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/spoken_confirm.dart';

void main() {
  test('parses english and hindi language choice', () {
    expect(SpokenConfirm.parseLanguage('Hindi please'), 'hi');
    expect(SpokenConfirm.parseLanguage('I want English'), 'en');
  });

  test('confirms yes and no', () {
    expect(SpokenConfirm.isYes('yes'), isTrue);
    expect(SpokenConfirm.isYes('haa'), isTrue);
    expect(SpokenConfirm.isYes('haan'), isTrue);
    expect(SpokenConfirm.isYes('हाँ'), isTrue);
    expect(SpokenConfirm.isYes('येस'), isTrue);
    expect(SpokenConfirm.isNo('no try again'), isTrue);
    expect(SpokenConfirm.isNo('naa'), isTrue);
    expect(SpokenConfirm.isNo('नहीं'), isTrue);
    expect(SpokenConfirm.isYes('that'), isFalse);
    expect(SpokenConfirm.isNo('name'), isFalse);
  });

  test('extracts phone digits from speech', () {
    expect(SpokenConfirm.digitsFromSpeech('nine eight seven six five four three two one zero'), '9876543210');
    expect(SpokenConfirm.digitsFromSpeech('98765 43210'), '9876543210');
  });
}

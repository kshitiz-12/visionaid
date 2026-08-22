import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/communication/domain/contact_matcher.dart';

void main() {
  const harry = PhoneContact(displayName: 'Harry Patel', phone: '9991110000');
  const mom = PhoneContact(displayName: 'Mom', phone: '7770001111');

  test('exact and first-name matches rank above weak contains', () {
    const other = PhoneContact(displayName: 'Mom', phone: '7770001111');
    final ranked = ContactMatcher.rank([harry, other], 'harry');
    expect(ranked.single.displayName, 'Harry Patel');
  });

  test('returns empty when nothing is close enough', () {
    final ranked = ContactMatcher.rank([harry, mom], 'uncle bob');
    expect(ranked, isEmpty);
  });

  test('dedupes same name and number', () {
    final ranked = ContactMatcher.rank([harry, harry], 'harry');
    expect(ranked.length, 1);
  });
}

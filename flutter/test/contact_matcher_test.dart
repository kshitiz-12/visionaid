import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/communication/domain/contact_matcher.dart';

void main() {
  const harry = PhoneContact(displayName: 'Harry Patel', phone: '9991110000');
  const mom = PhoneContact(displayName: 'Mom', phone: '7770001111');
  const mummyEmoji = PhoneContact(displayName: 'Mummy ❤️', phone: '8880002222');
  const hindiMom = PhoneContact(displayName: 'मम्मी 💕', phone: '6660003333');
  const priya = PhoneContact(
    displayName: 'Priya Sharma',
    phone: '5550004444',
    searchNames: ['Mummy'],
  );

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

  test('mummy matches mom and emoji display names', () {
    final ranked = ContactMatcher.rank([harry, mom, mummyEmoji], 'mummy');
    expect(ranked, isNotEmpty);
    expect(ranked.first.displayName, anyOf('Mom', 'Mummy ❤️'));
  });

  test('english mummy matches hindi contact name', () {
    final ranked = ContactMatcher.rank([harry, hindiMom], 'mummy');
    expect(ranked, isNotEmpty);
    expect(ranked.first.displayName, contains('मम्मी'));
  });

  test('mummy matches nickname field on legal name contact', () {
    final ranked = ContactMatcher.rank([harry, priya], 'mummy');
    expect(ranked.single.displayName, 'Priya Sharma');
  });

  test('fuzzy match handles small speech typos', () {
    const hari = PhoneContact(displayName: 'Harry Patel', phone: '9991110000');
    final ranked = ContactMatcher.rank([hari], 'hary');
    expect(ranked, isNotEmpty);
    expect(ranked.first.displayName, 'Harry Patel');
  });
}

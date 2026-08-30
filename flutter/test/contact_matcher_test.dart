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

  test('papa does not match unrelated pancho da contact', () {
    const pancho = PhoneContact(displayName: 'Pancho Da', phone: '1111111111');
    const gorai = PhoneContact(displayName: 'B Gorai', phone: '2222222222');
    const papa = PhoneContact(displayName: 'Papa', phone: '3333333333');
    final ranked = ContactMatcher.rank([pancho, gorai, papa], 'papa');
    expect(ranked, isNotEmpty);
    expect(ranked.first.displayName, 'Papa');
  });

  test('papa with no real match returns empty instead of fuzzy noise', () {
    const pancho = PhoneContact(displayName: 'Pancho Da', phone: '1111111111');
    const gorai = PhoneContact(displayName: 'B Gorai', phone: '2222222222');
    final ranked = ContactMatcher.rank([pancho, gorai], 'papa');
    expect(ranked, isEmpty);
  });

  test('mummy does not pull Mama or unrelated names via short alias', () {
    const mama = PhoneContact(displayName: 'Mama', phone: '4440005555');
    const gorai = PhoneContact(displayName: 'B Gorai', phone: '2222222222');
    final ranked = ContactMatcher.rank([mama, gorai, mom], 'mummy');
    expect(ranked.every((c) => c.displayName != 'Mama'), isTrue);
    expect(ranked.every((c) => c.displayName != 'B Gorai'), isTrue);
    expect(ranked, isNotEmpty);
    expect(ranked.first.displayName, 'Mom');
  });
}

class PhoneContact {
  const PhoneContact({required this.displayName, required this.phone});

  final String displayName;
  final String phone;
}

class ContactLookup {
  const ContactLookup({required this.matches, this.permissionDenied = false});

  final List<PhoneContact> matches;
  final bool permissionDenied;

  PhoneContact? get single => matches.length == 1 ? matches.first : null;
}

/// Pure name matching (unit-tested). Used against the full device address book.
class ContactMatcher {
  ContactMatcher._();

  static int score(String displayName, String query) {
    final name = _norm(displayName);
    final q = _norm(query);
    if (name.isEmpty || q.isEmpty) {
      return 0;
    }
    if (name == q) {
      return 100;
    }
    if (name.startsWith(q)) {
      return 90;
    }
    if (q.startsWith(name) && name.length >= 3) {
      return 88;
    }
    final nameParts = name.split(' ');
    final queryParts = q.split(' ');
    if (nameParts.any((p) => p == q)) {
      return 85;
    }
    if (name.contains(' $q') || name.contains('$q ')) {
      return 75;
    }
    if (name.contains(q) && q.length >= 3) {
      return 65;
    }
    var hits = 0;
    for (final part in queryParts) {
      if (part.length < 2) {
        continue;
      }
      if (nameParts.any((p) => p == part || p.startsWith(part) || part.startsWith(p))) {
        hits += 1;
      }
    }
    if (hits == queryParts.where((p) => p.length >= 2).length && hits > 0) {
      return 70;
    }
    return hits * 35;
  }

  static List<PhoneContact> rank(List<PhoneContact> contacts, String query) {
    final scored = <({PhoneContact c, int s})>[];
    for (final contact in contacts) {
      final s = score(contact.displayName, query);
      if (s >= 60) {
        scored.add((c: contact, s: s));
      }
    }
    scored.sort((a, b) => b.s.compareTo(a.s));
    final unique = <String, PhoneContact>{};
    for (final row in scored) {
      unique.putIfAbsent('${row.c.displayName}|${row.c.phone}', () => row.c);
    }
    return unique.values.take(5).toList();
  }

  static String _norm(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s\u0900-\u097F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

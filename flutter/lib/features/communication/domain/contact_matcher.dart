class PhoneContact {
  const PhoneContact({
    required this.displayName,
    required this.phone,
    this.searchNames = const [],
  });

  final String displayName;
  final String phone;

  /// All searchable name strings (display, first, last, nickname, …).
  final List<String> searchNames;
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

  /// Hindi / English nicknames and relationship terms that should match each other.
  static const _aliasGroups = <List<String>>[
    ['mummy', 'mom', 'mother', 'mum', 'mummi', 'mammi', 'amma', 'ammi', 'मम्मी', 'माँ', 'मां', 'अम्मा', 'अम्मी'],
    ['papa', 'dad', 'daddy', 'father', 'baba', 'abba', 'पापा', 'बाप', 'पिता', 'बाबा'],
    ['didi', 'sister', 'sis', 'दीदी', 'बहन'],
    ['bhai', 'brother', 'bro', 'भाई'],
    ['nana', 'grandpa', 'grandfather', 'dada', 'नाना', 'दादा'],
    ['nani', 'grandma', 'grandmother', 'dadi', 'नानी', 'दादी'],
    ['beta', 'son', 'बेटा'],
    ['beti', 'daughter', 'बेटी'],
    ['wife', 'patni', 'पत्नी', 'biwi', 'बीवी'],
    ['husband', 'pati', 'पति'],
  ];

  static int score(String displayName, String query, {List<String> extraNames = const []}) {
    final qForms = _forms(query);
    if (qForms.isEmpty) {
      return 0;
    }

    final family = _familyGroupContaining(query);
    var best = 0;
    final names = <String>{displayName, ...extraNames};
    for (final raw in names) {
      for (final name in _forms(raw)) {
        if (family != null) {
          // Relationship calls: exact alias membership only (mummy≠Mama).
          if (family.contains(name) || family.contains(_norm(raw))) {
            best = best > 100 ? best : 100;
          }
          for (final part in name.split(' ')) {
            if (family.contains(part)) {
              best = best > 95 ? best : 95;
            }
          }
          continue;
        }
        for (final q in qForms) {
          best = best > _pairScore(name, q) ? best : _pairScore(name, q);
        }
      }
    }
    return best;
  }

  static Set<String>? _familyGroupContaining(String query) {
    final base = _norm(query);
    if (base.isEmpty) {
      return null;
    }
    for (final group in _aliasGroups) {
      final normalized = group.map(_norm).where((s) => s.isNotEmpty).toSet();
      if (normalized.contains(base) ||
          base.split(' ').any(normalized.contains)) {
        return normalized;
      }
    }
    return null;
  }

  static List<PhoneContact> rank(List<PhoneContact> contacts, String query) {
    final scored = <({PhoneContact c, int s})>[];
    for (final contact in contacts) {
      final s = score(
        contact.displayName,
        query,
        extraNames: contact.searchNames,
      );
      if (s >= 70) {
        scored.add((c: contact, s: s));
      }
    }
    scored.sort((a, b) => b.s.compareTo(a.s));
    if (scored.isEmpty) {
      return [];
    }
    final best = scored.first.s;
    // Drop weak tail matches (e.g. "Pancho Da" when you said "papa").
    final cutoff = best >= 90 ? best - 18 : best - 8;
    final unique = <String, PhoneContact>{};
    for (final row in scored) {
      if (row.s < cutoff) {
        continue;
      }
      unique.putIfAbsent('${row.c.displayName}|${row.c.phone}', () => row.c);
    }
    return unique.values.take(5).toList();
  }

  static int _pairScore(String name, String q) {
    if (name.isEmpty || q.isEmpty) {
      return 0;
    }
    // Ultra-short tokens never prefix-match (ma → Mama / Manoj).
    if (q.length < 3) {
      return name == q ? 100 : 0;
    }
    if (name == q) {
      return 100;
    }
    if (name.startsWith(q) && q.length >= 4) {
      return 90;
    }
    if (q.startsWith(name) && name.length >= 4) {
      return 88;
    }
    final nameParts = name.split(' ');
    final queryParts = q.split(' ');
    if (nameParts.any((p) => p == q)) {
      return 85;
    }
    if (q.length >= 4 && (name.contains(' $q') || name.contains('$q '))) {
      return 75;
    }
    if (name.contains(q) && q.length >= 4) {
      return 65;
    }
    var hits = 0;
    for (final part in queryParts) {
      if (part.length < 3) {
        continue;
      }
      if (nameParts.any((p) => _tokenMatch(p, part))) {
        hits += 1;
      }
    }
    if (hits == queryParts.where((p) => p.length >= 3).length && hits > 0) {
      return 70;
    }
    final fuzzy = _fuzzyScore(name, q);
    if (fuzzy > 0) {
      return fuzzy;
    }
    for (final part in nameParts) {
      if (part.length < 3) {
        continue;
      }
      final tokenFuzzy = _fuzzyScore(part, q);
      if (tokenFuzzy > 0) {
        return tokenFuzzy;
      }
    }
    return hits * 35;
  }

  /// Avoid "dad" (papa alias) matching the surname "Da" in "Pancho Da".
  static bool _tokenMatch(String namePart, String queryPart) {
    if (namePart == queryPart) {
      return true;
    }
    if (namePart.length < 3 || queryPart.length < 3) {
      return false;
    }
    return namePart.startsWith(queryPart) || queryPart.startsWith(namePart);
  }

  static int _fuzzyScore(String name, String q) {
    if (q.length < 3 || name.length < 3) {
      return 0;
    }
    final shorter = name.length <= q.length ? name : q;
    final longer = name.length > q.length ? name : q;
    if (longer.length - shorter.length > 2) {
      return 0;
    }
    final dist = _editDistance(name, q);
    final maxLen = name.length > q.length ? name.length : q.length;
    final ratio = 1 - (dist / maxLen);
    if (ratio >= 0.82) {
      return (ratio * 78).round();
    }
    if (ratio >= 0.80 && q.length >= 4) {
      return (ratio * 88).round().clamp(72, 86);
    }
    if (ratio >= 0.76 && q.length >= 4) {
      return (ratio * 72).round();
    }
    if (ratio >= 0.72 && q.length >= 4) {
      return (ratio * 68).round();
    }
    return 0;
  }

  static int _editDistance(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    final prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      var corner = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final upper = prev[j];
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        prev[j] = _min3(prev[j] + 1, prev[j - 1] + 1, corner + cost);
        corner = upper;
      }
    }
    return prev[b.length];
  }

  static int _min3(int a, int b, int c) {
    var m = a;
    if (b < m) {
      m = b;
    }
    if (c < m) {
      m = c;
    }
    return m;
  }

  static Set<String> _forms(String raw) {
    final base = _norm(raw);
    if (base.isEmpty) {
      return {};
    }
    final out = <String>{base};
    for (final group in _aliasGroups) {
      final normalized = group.map(_norm).where((s) => s.isNotEmpty).toSet();
      if (normalized.contains(base)) {
        out.addAll(normalized);
      }
    }
    for (final token in base.split(' ')) {
      if (token.length < 2) {
        continue;
      }
      for (final group in _aliasGroups) {
        final normalized = group.map(_norm).where((s) => s.isNotEmpty).toSet();
        if (normalized.contains(token)) {
          out.addAll(normalized);
        }
      }
    }
    return out;
  }

  static String _norm(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\u0900-\u097F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

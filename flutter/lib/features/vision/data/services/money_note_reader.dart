/// Reads printed denomination on a note. Not a bank-grade counter.
class MoneyNoteReader {
  MoneyNoteReader._();

  static const labels = {
    'money',
    'cash',
    'currency',
    'banknote',
    'bank note',
    'rupee',
    'rupees',
    'coin',
    'dollar',
    'bill',
  };

  static bool looksLikeCash(Iterable<String> names) {
    for (final n in names) {
      final t = n.toLowerCase();
      if (labels.contains(t)) {
        return true;
      }
      if (t.contains('money') ||
          t.contains('currency') ||
          t.contains('rupee') ||
          t.contains('cash') ||
          t.contains('banknote')) {
        return true;
      }
    }
    return false;
  }

  static String? speakFromOcr(String raw) {
    final t = raw.toLowerCase().replaceAll(',', '');
    if (t.trim().isEmpty) {
      return null;
    }

    final rupeeHint = t.contains('rupee') ||
        t.contains('india') ||
        t.contains('rbi') ||
        t.contains('₹');

    const notes = [2000, 500, 200, 100, 50, 20, 10];
    for (final n in notes) {
      if (RegExp('\\b$n\\b').hasMatch(t) || t.contains('₹$n') || t.contains('rs $n')) {
        return rupeeHint || !t.contains(r'$')
            ? 'This looks like $n rupees. Hold it still if you want me to check again.'
            : 'This looks like $n. Hold it still if you want me to check again.';
      }
    }

    final dollar = RegExp(r'\$\s*(\d+)').firstMatch(t);
    if (dollar != null) {
      return 'This looks like ${dollar.group(1)} dollars.';
    }

    if (looksLikeCash(t.split(RegExp(r'\s+')))) {
      return 'That looks like money, but I cannot read the amount yet. Hold the note flatter.';
    }
    return null;
  }
}

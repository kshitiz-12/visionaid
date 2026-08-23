class ResearchLogRow {
  ResearchLogRow({
    required this.timestamp,
    required this.object,
    required this.line,
  });

  final DateTime timestamp;
  final String object;
  final String line;
}

class ResearchLogger {
  final List<ResearchLogRow> rows = [];

  void record(String line, {String object = '', DateTime? timestamp}) {
    rows.add(
      ResearchLogRow(
        timestamp: timestamp ?? DateTime.now(),
        object: object,
        line: line,
      ),
    );
    while (rows.length > 200) {
      rows.removeAt(0);
    }
  }
}

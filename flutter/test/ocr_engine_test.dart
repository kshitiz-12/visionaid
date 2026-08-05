import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/ocr/data/repositories/ocr_repository_impl.dart';
import 'package:visionaid/features/ocr/domain/services/ocr_engine.dart';

void main() {
  group('ocr engine', () {
    test('extracts and prioritizes readable text in scene', () async {
      final engine = OcrEngine(repository: OcrRepositoryImpl());

      final blocks = [
        {
          'text': 'EXIT',
          'confidence': 0.97,
          'priority': 0.95,
          'isCritical': true,
        },
        {
          'text': 'Cafe menu',
          'confidence': 0.74,
          'priority': 0.35,
          'isCritical': false,
        },
      ];

      final results = await engine.extractText(blocks);

      expect(results.isNotEmpty, isTrue);
      expect(results.first.text, 'EXIT');
      expect(results.first.isCritical, isTrue);
      expect(engine.summarizeReading(results), contains('EXIT'));
    });
  });
}

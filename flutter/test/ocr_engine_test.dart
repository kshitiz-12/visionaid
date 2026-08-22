import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/features/ocr/data/mlkit_ocr_engine.dart';

void main() {
  test('OCR engine is constructible for on-device text recognition', () {
    final engine = MlKitOcrEngine();
    expect(engine, isNotNull);
  });
}

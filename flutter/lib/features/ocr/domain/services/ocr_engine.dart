abstract class OcrEngine {
  Future<String> recognizeText(String imagePath);
  Future<void> dispose();
}

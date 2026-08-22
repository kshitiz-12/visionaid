import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/services/ocr_engine.dart';

class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<String> recognizeText(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw StateError('Captured image not found.');
    }

    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text.trim();
  }

  @override
  Future<void> dispose() => _recognizer.close();
}

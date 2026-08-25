import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureService {
  Future<String> captureStill() async {
    final shot = await captureJpeg();
    return shot.path;
  }

  /// JPEG on disk plus a small base64 frame for cloud vision.
  Future<({String path, String imageBase64})> captureJpeg() async {
    final path = await _takePicture();
    final encoded = await _compactJpeg(path);
    return (path: path, imageBase64: encoded);
  }

  Future<String> _takePicture() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw StateError('Camera permission is required. Enable it in settings.');
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No camera found on this device.');
    }

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      final file = await controller.takePicture();
      return file.path;
    } on CameraException catch (error) {
      throw StateError(
        'Camera failed: ${error.description ?? error.code}. Try again.',
      );
    } finally {
      await controller.dispose();
    }
  }

  Future<String> _compactJpeg(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return base64Encode(bytes);
    }
    final width = decoded.width > 640 ? 640 : decoded.width;
    final resized = img.copyResize(decoded, width: width);
    final jpeg = img.encodeJpg(resized, quality: 45);
    return base64Encode(jpeg);
  }
}

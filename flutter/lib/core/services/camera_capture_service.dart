import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Captures a single still frame from the back camera for on-device analysis.
class CameraCaptureService {
  Future<String> captureStill() async {
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
      // Let auto-exposure settle so the first frame is usable.
      await Future<void>.delayed(const Duration(milliseconds: 800));
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
}

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Converts a live [CameraImage] into an ML Kit [InputImage].
InputImage? inputImageFromCamera({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final rotation = _rotation(camera, deviceOrientation);
  if (rotation == null) {
    return null;
  }

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) {
    return null;
  }
  if (Platform.isAndroid &&
      format != InputImageFormat.nv21 &&
      format != InputImageFormat.yuv_420_888 &&
      format != InputImageFormat.yv12) {
    return null;
  }
  if (Platform.isIOS &&
      format != InputImageFormat.bgra8888 &&
      format != InputImageFormat.yuv420) {
    return null;
  }

  final bytes = WriteBuffer();
  for (final plane in image.planes) {
    bytes.putUint8List(plane.bytes);
  }

  return InputImage.fromBytes(
    bytes: bytes.done().buffer.asUint8List(),
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}

InputImageRotation? _rotation(
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  const orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final sensor = camera.sensorOrientation;
  if (Platform.isIOS) {
    return InputImageRotationValue.fromRawValue(sensor);
  }

  var compensation = orientations[deviceOrientation] ?? 0;
  if (camera.lensDirection == CameraLensDirection.front) {
    compensation = (sensor + compensation) % 360;
  } else {
    compensation = (sensor - compensation + 360) % 360;
  }
  return InputImageRotationValue.fromRawValue(compensation);
}

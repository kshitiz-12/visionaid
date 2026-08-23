import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Converts a live [CameraImage] into an ML Kit [InputImage].
///
/// Concatenating YUV planes as-is produces garbage and empty detections.
/// NV21 / BGRA use the first plane; YUV420 is packed into NV21.
InputImage? inputImageFromCamera({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final rotation = _rotation(camera, deviceOrientation);
  if (rotation == null) {
    return null;
  }

  final packed = _packedBytes(image);
  if (packed == null || packed.bytes.isEmpty) {
    return null;
  }

  return InputImage.fromBytes(
    bytes: packed.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: packed.format,
      bytesPerRow: packed.bytesPerRow,
    ),
  );
}

class _Packed {
  const _Packed({
    required this.bytes,
    required this.format,
    required this.bytesPerRow,
  });

  final Uint8List bytes;
  final InputImageFormat format;
  final int bytesPerRow;
}

_Packed? _packedBytes(CameraImage image) {
  if (Platform.isIOS) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }
    return _Packed(
      bytes: image.planes.first.bytes,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
  }

  if (image.format.group == ImageFormatGroup.nv21 || image.planes.length == 1) {
    return _Packed(
      bytes: image.planes.first.bytes,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
  }

  final nv21 = _yuv420ToNv21(image);
  if (nv21 == null) {
    return null;
  }
  return _Packed(
    bytes: nv21,
    format: InputImageFormat.nv21,
    bytesPerRow: image.width,
  );
}

Uint8List? _yuv420ToNv21(CameraImage image) {
  if (image.planes.length < 3) {
    return null;
  }

  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final yRowStride = yPlane.bytesPerRow;
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  final nv21 = Uint8List(width * height * 3 ~/ 2);
  var dst = 0;

  for (var row = 0; row < height; row++) {
    final src = row * yRowStride;
    final len = width;
    if (src + len > yPlane.bytes.length || dst + len > nv21.length) {
      return null;
    }
    nv21.setRange(dst, dst + len, yPlane.bytes, src);
    dst += len;
  }

  final uvHeight = height ~/ 2;
  final uvWidth = width ~/ 2;
  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      final uvIndex = row * uvRowStride + col * uvPixelStride;
      if (uvIndex >= vPlane.bytes.length || uvIndex >= uPlane.bytes.length) {
        return null;
      }
      if (dst + 1 >= nv21.length) {
        return null;
      }
      nv21[dst++] = vPlane.bytes[uvIndex];
      nv21[dst++] = uPlane.bytes[uvIndex];
    }
  }

  return nv21;
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

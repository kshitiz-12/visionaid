import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../core/network/companion_client.dart';
import '../../../../core/services/user_prefs.dart';
import '../../domain/services/object_detector_service.dart';

/// Silent one-shot Gemini ID when YOLO is close but unsure. 6 s cooldown.
class YoloGeminiFallback {
  YoloGeminiFallback(this._companion);

  final CompanionClient _companion;
  DateTime? _last;
  bool _busy = false;

  static const cooldown = Duration(seconds: 6);

  /// True when a capture is allowed right now (cooldown + not busy).
  bool get canCapture {
    if (_busy) {
      return false;
    }
    if (_last == null) {
      return true;
    }
    return DateTime.now().difference(_last!) >= cooldown;
  }

  bool shouldTrigger(List<RawDetection> detections) {
    if (!canCapture) {
      return false;
    }
    for (final d in detections) {
      final metres = d.distanceMeters;
      final close = metres != null ? metres <= 1.2 : d.distance >= 0.22;
      final unsure = d.confidence < 0.40;
      final unnamed = d.label == 'obstacle' ||
          d.label == 'object' ||
          d.label.contains('thing');
      if (close && (unsure || unnamed)) {
        return true;
      }
    }
    return false;
  }

  Future<String?> identify({
    required Uint8List jpeg,
    required List<RawDetection> detections,
  }) async {
    if (_busy) {
      return null;
    }
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < cooldown) {
      return null;
    }
    if (!shouldTrigger(detections)) {
      return null;
    }
    _busy = true;
    _last = now;
    try {
      final small = _compress(jpeg);
      if (small.isEmpty) {
        return null;
      }
      final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
      final reply = await _companion.chat(
        message:
            'Name the closest obstacle in one short spoken sentence. Use left, slight left, ahead, slight right, or right. Say close, one metre, or two metres.',
        language: lang.code,
        imageBase64: base64Encode(small),
      );
      final text = reply.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  Uint8List _compress(Uint8List jpeg) {
    try {
      final decoded = img.decodeImage(jpeg);
      if (decoded == null) {
        return Uint8List(0);
      }
      final resized = decoded.width > 640
          ? img.copyResize(decoded, width: 640)
          : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 42));
    } catch (_) {
      return Uint8List(0);
    }
  }
}

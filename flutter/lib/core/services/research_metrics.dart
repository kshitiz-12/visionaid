import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../features/walking/data/walking_latency.dart';

/// On-device study metrics for academic evaluation (no cloud upload).
class ResearchMetrics {
  ResearchMetrics._();
  static final instance = ResearchMetrics._();

  final List<Map<String, Object?>> _events = [];
  DateTime? sessionStartedAt;
  String sessionId = '';

  void startSession({String label = 'walk'}) {
    sessionStartedAt = DateTime.now();
    sessionId =
        '${label}_${sessionStartedAt!.millisecondsSinceEpoch}';
    _events.clear();
    log('session_start', {'label': label});
  }

  void log(String type, [Map<String, Object?> data = const {}]) {
    _events.add({
      't': DateTime.now().toIso8601String(),
      'type': type,
      ...data,
    });
  }

  void logLatency(WalkingLatency latency, {required double fps}) {
    log('latency', {
      'cam_to_det_ms': latency.cameraToDetectionMs,
      'total_ms': latency.hazardToTtsMs,
      'fps': double.parse(fps.toStringAsFixed(1)),
      'depth_source': 'walking',
    });
  }

  void logAnnouncement({
    required String spoken,
    required String label,
    required bool safety,
  }) {
    log('announce', {
      'spoken': spoken,
      'label': label,
      'safety': safety,
    });
  }

  void logDetection({
    required String label,
    required double confidence,
    double? metres,
  }) {
    log('detect', {
      'label': label,
      'confidence': double.parse(confidence.toStringAsFixed(3)),
      'metres': metres,
    });
  }

  int get announcementCount =>
      _events.where((e) => e['type'] == 'announce').length;

  List<int> get totalLatenciesMs => _events
      .where((e) => e['type'] == 'latency' && e['total_ms'] is int)
      .map((e) => e['total_ms']! as int)
      .where((ms) => ms >= 0)
      .toList();

  double? get meanLatencyMs {
    final list = totalLatenciesMs;
    if (list.isEmpty) {
      return null;
    }
    return list.reduce((a, b) => a + b) / list.length;
  }

  Map<String, Object?> summary() {
    return {
      'session_id': sessionId,
      'started_at': sessionStartedAt?.toIso8601String(),
      'event_count': _events.length,
      'announcement_count': announcementCount,
      'mean_latency_ms': meanLatencyMs,
      'target_latency_ms': 150,
    };
  }

  Future<File> persist() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/visionaid_study_$sessionId.json');
    final payload = {
      'summary': summary(),
      'events': _events,
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }
}

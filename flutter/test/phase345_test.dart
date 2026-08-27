import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/research_metrics.dart';
import 'package:visionaid/features/intent/data/intent_engine_impl.dart';
import 'package:visionaid/features/intent/domain/entities/user_intent.dart';
import 'package:visionaid/features/walking/data/monocular_depth_estimator.dart';

void main() {
  test('navigate to extracts outdoor destination', () async {
    final engine = IntentEngineImpl();
    final intent = await engine.classify('Navigate to Central Park');
    expect(intent.type, IntentType.routeNavigate);
    expect(intent.target.toLowerCase(), contains('central park'));
  });

  test('take me to is outdoor route, guide me is live walk', () async {
    final engine = IntentEngineImpl();
    final route = await engine.classify('Take me to the railway station');
    expect(route.type, IntentType.routeNavigate);
    expect(route.target.toLowerCase(), contains('railway'));

    final walk = await engine.classify('Guide me');
    expect(walk.type, IntentType.navigation);
  });

  test('research metrics counts announcements and mean latency', () {
    final m = ResearchMetrics.instance;
    m.startSession(label: 'unit');
    m.logAnnouncement(spoken: 'Chair ahead', label: 'chair', safety: false);
    m.log('latency', {'total_ms': 120});
    m.log('latency', {'total_ms': 180});
    expect(m.announcementCount, 1);
    expect(m.meanLatencyMs, closeTo(150, 0.01));
  });

  test('midas metres fusion prefers nearer inverse depth', () {
    final est = MonocularDepthEstimator();
    final map = Float32List(MonocularDepthEstimator.inputSize *
        MonocularDepthEstimator.inputSize);
    for (var y = 0; y < MonocularDepthEstimator.inputSize; y++) {
      for (var x = 0; x < MonocularDepthEstimator.inputSize; x++) {
        map[y * MonocularDepthEstimator.inputSize + x] =
            x < MonocularDepthEstimator.inputSize / 2 ? 1.0 : 0.1;
      }
    }
    est.debugSetMap(map);
    final near = est.metresInRegion(
      left: 0.1,
      top: 0.4,
      right: 0.2,
      bottom: 0.6,
      boxFallbackMetres: 2.0,
    );
    final far = est.metresInRegion(
      left: 0.8,
      top: 0.4,
      right: 0.9,
      bottom: 0.6,
      boxFallbackMetres: 2.0,
    );
    expect(near, isNotNull);
    expect(far, isNotNull);
    expect(near!, lessThan(far!));
  });
}

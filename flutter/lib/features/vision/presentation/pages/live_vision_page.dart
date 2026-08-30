import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../../core/providers/agent_providers.dart';
import '../../../../core/providers/pipeline_providers.dart';
import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/research_metrics.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../../core/widgets/multi_tap_tracker.dart';
import '../../../../core/widgets/two_finger_down.dart';
import '../../../../services/imu_tracker.dart';
import '../../../../services/memory_tracker.dart';
import '../../../../services/priority_audio.dart';
import '../../../../services/spatial_db.dart';
import '../../../../services/spatial_fusion.dart';
import '../../../guide_alerts/data/guide_alert_engine.dart';
import '../../../guide_alerts/data/object_priority_engine.dart';
import '../../../guide_alerts/data/voice_announcement_queue.dart';
import '../../../guide_alerts/domain/guide_config.dart';
import '../../../guide_alerts/domain/guide_models.dart';
import '../../../walking/data/hazard_cue.dart';
import '../../../walking/data/monocular_depth_estimator.dart';
import '../../../walking/data/motion_adaptive_throttle.dart';
import '../../../walking/data/walking_latency.dart';
import '../../../walking/data/walking_pipeline.dart';
import '../../data/services/camera_image_converter.dart';
import '../../data/services/mlkit_object_detector.dart';
import '../../data/services/scene_labeler.dart';
import '../../data/services/scene_speech_filter.dart';
import '../../data/services/yolo_gemini_fallback.dart';
import '../../data/services/yolo_mapper.dart';
import '../../data/services/yolo_object_detector.dart';
import '../../domain/services/object_detector_service.dart';

/// On-device walking loop. CameraX ImageAnalysis uses KEEP_ONLY_LATEST;
/// [_busyFrame] drops work when inference is behind so only the newest frame is used.
class LiveVisionPage extends ConsumerStatefulWidget {
  const LiveVisionPage({super.key, this.findTarget = ''});

  final String findTarget;

  @override
  ConsumerState<LiveVisionPage> createState() => _LiveVisionPageState();
}

class _LiveVisionPageState extends ConsumerState<LiveVisionPage> {
  CameraController? _controller;
  bool _busyFrame = false;
  bool _starting = true;
  bool _streaming = false;
  String _status = 'Starting live vision…';
  bool _alert = false;
  int _badFrames = 0;
  GuideAlertEngine? _alerts;
  VoiceAnnouncementQueue? _queue;
  final _walk = WalkingPipeline();
  bool _voiceLoop = false;
  final _hazard = HazardCue();
  final _motionFrames = MotionAdaptiveThrottle();
  MlKitObjectDetector? _guideDetector;
  SceneLabeler? _guideLabeler;
  List<RawDetection> _lastNames = const [];
  late final MultiTapTracker _taps;
  late final TwoFingerDown _twoFingers;
  bool _emergencyBusy = false;
  bool _closing = false;
  bool _wasBlocked = false;
  int _clearFrames = 0;
  int _beepBlockFrames = 0;
  DateTime? _saidClearAt;
  bool _useYolo = true;
  String _yoloModelPath = YoloObjectDetector.modelId();
  final _yoloCtrl = YOLOViewController();
  YoloGeminiFallback? _geminiFallback;
  List<RawDetection> _hazards = const [];
  List<RawDetection> _scenePerception = const [];
  DateTime? _scenePerceptionAt;
  bool _scenePerceptionBusy = false;
  MlKitObjectDetector? _sceneDetector;
  DateTime? _lastSceneNarrationAt;
  String _lastSceneSignature = '';
  DateTime? _lastTargetSpeechAt;
  String _lastTargetSpeech = '';
  DateTime? _depthAt;
  bool _depthBusy = false;
  bool _agentReady = false;
  bool _followMe = false;
  DateTime? _lastPriorityAt;
  static const _liveMemoryNodeId = 'living_room';
  bool _liveMemoryNodeReady = false;

  static const _criticalLabels = {
    'stairs',
    'ladder',
    'vehicle',
    'car',
    'truck',
    'bus',
    'motorcycle',
    'bicycle',
    'pothole',
    'open_drain',
    'curb',
    'person',
  };

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _taps = MultiTapTracker(
      onSingle: () {},
      onDouble: () {
        if (_closing) {
          return;
        }
        unawaited(HapticFeedback.mediumImpact());
        unawaited(_leave());
      },
      onTriple: () => unawaited(_emergencyFromWalk()),
    );
    _twoFingers = TwoFingerDown(onTwo: () {
      unawaited(_quitApp());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final tts = ref.read(textToSpeechProvider);
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    final finding = widget.findTarget.trim();
    final modes = ref.read(appModeControllerProvider);
    if (finding.isNotEmpty) {
      modes.enterTargetSearch(finding);
    } else {
      modes.enterHazardNavigation();
    }
    _alerts = GuideAlertEngine(
      config: finding.isEmpty ? GuideConfig.hazardOnly : const GuideConfig(),
      hindi: lang.code.toLowerCase().startsWith('hi'),
    );
    if (widget.findTarget.trim().isNotEmpty) {
      _alerts!.startTargetSearch(widget.findTarget);
    }
    _queue ??= VoiceAnnouncementQueue(tts);
    _geminiFallback ??= YoloGeminiFallback(ref.read(companionClientProvider));
    _guideLabeler ??= SceneLabeler();
    await _walk.warmup();
    await _ensureAgentServices();
    _yoloModelPath = await YoloObjectDetector.resolveModelPath();
    await _motionFrames.start();
    ResearchMetrics.instance.startSession(
      label: widget.findTarget.trim().isEmpty ? 'walk' : 'find',
    );

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _starting = false;
        _status = 'Camera permission is required.';
        _alert = true;
      });
      await tts.speak(_status);
      return;
    }

    _streaming = true;
    unawaited(_yoloCtrl.setShowOverlays(false));
    final hi = lang.code.toLowerCase().startsWith('hi');
    setState(() {
      _starting = false;
      if (finding.isNotEmpty) {
        _status = hi
            ? '$finding ढूँढ रहे हैं. धीरे घुमाइए. कंपन मार्गदर्शन चालू है.'
            : 'Looking for $finding. Sweep slowly. Vibration guides you closer.';
      } else {
        _status = hi ? 'आगे देखें.' : 'Look ahead.';
      }
    });
    unawaited(tts.speak(_status));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_streaming && mounted) {
      unawaited(_refreshScenePerception());
    }
    if (_streaming && mounted) {
      _armStopPhrase();
    }
  }

  void _onYolo(List<YOLOResult> results) {
    if (!_streaming || _closing || !_useYolo) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_motionFrames.shouldSkip(busy: _busyFrame, nowMs: now)) {
      return;
    }
    _busyFrame = true;
    unawaited(() async {
      try {
        final objects = [
          ...YoloMapper.toRaw(results),
          ..._hazards,
          ..._scenePerception,
        ];
        await _ingestWalk(objects, fromYolo: true);
        unawaited(_refreshScenePerception());
        unawaited(_refreshDepth());
      } finally {
        _busyFrame = false;
      }
    }());
  }

  Future<void> _refreshDepth() async {
    final fused = _walk.fusedDepth;
    if (fused == null || !fused.midas.available || _depthBusy || !_streaming) {
      return;
    }
    final now = DateTime.now();
    if (_depthAt != null &&
        now.difference(_depthAt!) < const Duration(milliseconds: 2200)) {
      return;
    }
    _depthBusy = true;
    _depthAt = now;
    try {
      final jpeg = await _yoloCtrl.capturePhoto(withOverlays: false);
      if (jpeg == null || jpeg.isEmpty) {
        return;
      }
      await fused.midas.estimateJpeg(jpeg);
    } catch (_) {
      // Depth is assistive; box-size remains.
    } finally {
      _depthBusy = false;
    }
  }

  /// Custom hazard YOLO misses COCO objects (laptop, cup, person). ML Kit + labels fill the scene.
  Future<void> _refreshScenePerception() async {
    if (!_useYolo || _scenePerceptionBusy || !_streaming) {
      return;
    }
    final now = DateTime.now();
    if (_scenePerceptionAt != null &&
        now.difference(_scenePerceptionAt!) <
            const Duration(milliseconds: 1100)) {
      return;
    }
    final labeler = _guideLabeler;
    if (labeler == null) {
      return;
    }
    _scenePerceptionBusy = true;
    _scenePerceptionAt = now;
    try {
      _sceneDetector ??= MlKitObjectDetector(stream: false);
      final jpeg = await _yoloCtrl.capturePhoto(withOverlays: false);
      if (jpeg == null || jpeg.isEmpty) {
        return;
      }
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}visionaid_scene.jpg',
      );
      await file.writeAsBytes(jpeg, flush: true);
      final boxes = await _sceneDetector!.detect(file.path);
      final labels = await labeler.labelFile(file.path);
      final merged = SceneLabeler.merge(
        boxes,
        labels,
        includeLabelOnly: ref.read(appModeControllerProvider).isTargetSearch,
      );
      _scenePerception = merged;
      _hazards = YoloMapper.hazardBoxesFromLabels(merged);
    } catch (_) {
      // Keep last perception; ML Kit is best-effort.
    } finally {
      _scenePerceptionBusy = false;
    }
  }

  Future<void> _onYoloReady(String path, YOLOTask? task) async {
    await _yoloCtrl.setShowOverlays(false);
    await _yoloCtrl.setConfidenceThreshold(0.18);
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _alerts?.hindi == true
          ? 'आगे देखें. धीरे चलें.'
          : 'Look ahead. Walk slowly.';
    });
  }

  Future<void> _onYoloError(Object error, String path, YOLOTask? task) async {
    if (!_useYolo) {
      return;
    }
    _useYolo = false;
    if (mounted) {
      setState(() {
        _status = _alerts?.hindi == true
            ? 'YOLO नहीं चला. पुराना कैमरा इस्तेमाल हो रहा है.'
            : 'YOLO failed. Using the backup camera.';
      });
    }
    // Release YOLO's CameraX session before opening Flutter camera.
    await _yoloCtrl.stop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_streaming || !mounted) {
      return;
    }
    await _startMlKitCamera();
  }

  Future<void> _startMlKitCamera() async {
    _guideDetector ??= MlKitObjectDetector(stream: true);
    _guideLabeler ??= SceneLabeler();
    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) {
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    CameraController? controller;
    try {
      controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
    } catch (_) {
      await controller?.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    setState(() {});
    await controller.startImageStream(_onFrame);
  }

  Future<void> _ingestWalk(
    List<RawDetection> objects, {
    required bool fromYolo,
  }) async {
    if (!_streaming || _alerts == null) {
      return;
    }
    final modes = ref.read(appModeControllerProvider);
    final targetSearch = modes.isTargetSearch ||
        widget.findTarget.trim().isNotEmpty ||
        modes.searchTarget.isNotEmpty;
    objects = SceneSpeechFilter.forPipeline(
      objects,
      targetSearch: targetSearch,
    );
    final latency = WalkingLatency()
      ..frameCapturedMs = DateTime.now().millisecondsSinceEpoch
      ..inferenceCompletedMs = DateTime.now().millisecondsSinceEpoch;
    final tick = _walk.tick(raw: objects, latency: latency);
    final finding = widget.findTarget.trim();
    final anchor = tick.snapshots.isEmpty
        ? null
        : tick.snapshots
                .map((s) => s.centerX ?? 0.5)
                .reduce((a, b) => a + b) /
            tick.snapshots.length;
    _motionFrames.noteScene(
      anchorX: anchor,
      forcedMove: tick.occupancy.blocked,
    );
    if (finding.isNotEmpty) {
      final hit = _bestTargetSnap(tick.snapshots, finding);
      if (hit != null) {
        await _driveTargetGeiger(hit);
      }
    } else if (tick.occupancy.blocked) {
      _beepBlockFrames += 1;
      // Need a few blocked frames so flicker / far box-size guesses don't beep.
      if (_beepBlockFrames >= 3) {
        await _hazard.pingIfWithinMetre(
          tick.occupancy.closestMetres,
          pathBlocked: true,
        );
      }
    } else {
      _beepBlockFrames = 0;
    }
    if (fromYolo) {
      if (modes.allowAmbientSceneSpeech) {
        unawaited(_maybeGemini(objects));
      }
    }
    unawaited(_streamDetectionsToMemory(tick.snapshots, objects));
    unawaited(_runSpatialAgent(tick.snapshots, objects));

    final guideMode =
        modes.isTargetSearch ? GuideMode.targetSearch : GuideMode.liveGuide;
    final result = _alerts!.evaluateSnapshots(
      snapshots: tick.snapshots,
      mode: guideMode,
      findTarget: modes.searchTarget.isNotEmpty
          ? modes.searchTarget
          : widget.findTarget,
    );

    // TARGET_SEARCH: completely mute path-clear TTS.
    if (modes.allowPathClearSpeech) {
      if (tick.occupancy.blocked) {
        _wasBlocked = true;
        _clearFrames = 0;
      } else if (_wasBlocked &&
          result.announcements.isEmpty &&
          !(_queue?.isPlaying ?? false)) {
        _clearFrames += 1;
        final now = DateTime.now();
        final due = _saidClearAt == null ||
            now.difference(_saidClearAt!) > const Duration(seconds: 10);
        if (due && _clearFrames >= 4) {
          _wasBlocked = false;
          _clearFrames = 0;
          _saidClearAt = now;
          final clear =
              _alerts?.hindi == true ? 'रास्ता साफ़.' : 'Path clear.';
          if (mounted) {
            setState(() {
              _status = clear;
              _alert = false;
            });
          }
          unawaited(
            _queue?.submit(
              GuideAnnouncement(
                spoken: clear,
                decision: AnnouncementDecision.announce,
                band: PriorityBand.announce,
                priorityScore: 1,
                trackKey: 'path-clear',
                label: 'path',
                speechPriority: SpeechPriority.low,
              ),
            ),
          );
        }
      } else {
        _clearFrames = 0;
      }
    } else {
      _wasBlocked = false;
      _clearFrames = 0;
    }

    if (result.announcements.isEmpty) {
      return;
    }

    final alert = result.announcements.first;

    // In TARGET_SEARCH only allow target hits, not-found, or crash-range safety.
    if (modes.isTargetSearch) {
      final isTarget =
          alert.decision == AnnouncementDecision.announceTarget;
      final isNotFound = alert.decision == AnnouncementDecision.notFound;
      final crashOk = modes.allowHazardInterrupt(
        depthMetres: tick.occupancy.closestMetres,
        safetyCritical: alert.safetyOverride,
      );
      if (!isTarget && !isNotFound && !crashOk) {
        return;
      }
      if (isTarget) {
        // Sparse speech + continuous haptic (already pulsed above).
        final now = DateTime.now();
        if (_lastTargetSpeech == alert.spoken &&
            _lastTargetSpeechAt != null &&
            now.difference(_lastTargetSpeechAt!) <
                const Duration(seconds: 8)) {
          return;
        }
        _lastTargetSpeech = alert.spoken;
        _lastTargetSpeechAt = now;
      }
    }

    latency.decisionCompletedMs = DateTime.now().millisecondsSinceEpoch;
    latency.ttsTriggeredMs = DateTime.now().millisecondsSinceEpoch;
    ResearchMetrics.instance.logLatency(latency, fps: tick.fps);
    ResearchMetrics.instance.logAnnouncement(
      spoken: alert.spoken,
      label: alert.label,
      safety: alert.safetyOverride,
    );
    if (mounted) {
      setState(() {
        _status = alert.spoken;
        _alert = alert.safetyOverride ||
            alert.band == PriorityBand.critical ||
            alert.band == PriorityBand.highPriority;
      });
    }
    unawaited(_queue?.submit(alert));
  }

  Future<void> _driveTargetGeiger(GuideObjectSnapshot hit) async {
    final audio = ref.read(priorityAudioProvider);
    final z = hit.distanceMeters ??
        (hit.boxProximity >= 0.45
            ? 0.5
            : (hit.boxProximity >= 0.22 ? 1.2 : 2.5));
    final angle = ((hit.centerX ?? 0.5) - 0.5) * 60.0;
    try {
      await audio.pulseTargetGeiger(
        depthZMetres: z,
        angleXDegrees: angle,
      );
    } catch (_) {}
  }

  Future<void> _ensureAgentServices() async {
    try {
      await ref.read(spatialAgentReadyProvider.future);
      if (mounted) {
        setState(() => _agentReady = true);
      } else {
        _agentReady = true;
      }
    } catch (error) {
      _agentReady = false;
      if (mounted) {
        setState(() {
          _status =
              'Spatial agent offline ($error). On-device walking still works.';
          _alert = true;
        });
      }
    }
  }

  Future<void> _ensureLiveMemoryNode(SpatialDb db) async {
    if (_liveMemoryNodeReady) {
      return;
    }
    await db.upsertNode(
      const SpatialNode(
        id: _liveMemoryNodeId,
        label: 'living room',
        type: 'place',
      ),
    );
    _liveMemoryNodeReady = true;
  }

  /// Continuously logs every camera detection into SQLite object memory.
  Future<void> _streamDetectionsToMemory(
    List<GuideObjectSnapshot> snaps,
    List<RawDetection> raw,
  ) async {
    if (!_streaming || _closing) {
      return;
    }
    final db = ref.read(spatialDbProvider);
    final memory = ref.read(memoryTrackerProvider);
    final nodes = ref.read(activeNodeStoreProvider);
    if (!db.isOpen) {
      return;
    }

    var nodeId = nodes.activeNodeId?.trim() ?? '';
    if (nodeId.isNotEmpty) {
      final node = await db.getNode(nodeId);
      if (node == null) {
        nodeId = '';
      }
    }
    if (nodeId.isEmpty) {
      await _ensureLiveMemoryNode(db);
      nodeId = _liveMemoryNodeId;
    }

    final fusion = ref.read(spatialFusionProvider);
    final midas = _walk.fusedDepth?.midas;
    final depthMap = midas?.lastMap;
    final byLabel = <String, SpatialVector>{};
    if (depthMap != null) {
      for (final snap in snaps) {
        final box = snap.boundingBox;
        if (box == null || snap.label.trim().isEmpty) {
          continue;
        }
        try {
          final vector = fusion.computeVector(
            label: snap.label,
            depthMap: depthMap,
            mapWidth: MonocularDepthEstimator.inputSize,
            mapHeight: MonocularDepthEstimator.inputSize,
            box: NormalizedBoundingBox(
              x1: box.left,
              y1: box.top,
              x2: box.right,
              y2: box.bottom,
            ),
          );
          byLabel[snap.label.toLowerCase()] = vector;
        } on SpatialFusionException {
          continue;
        }
      }
    }

    if (raw.isEmpty) {
      return;
    }

    try {
      await memory.observeDetections(
        currentNodeId: nodeId,
        logAllLabels: true,
        detections: [
          for (final d in raw)
            TrackedDetection(
              label: d.label,
              confidence: d.confidence,
              relativeVectorX: byLabel[d.label.toLowerCase()]?.angleXDegrees,
              depthZ: byLabel[d.label.toLowerCase()]?.depthZMeters ??
                  d.distanceMeters,
              boxArea: d.boxWidth > 0 && d.boxHeight > 0
                  ? (d.boxWidth * d.boxHeight).clamp(0.0, 1.0)
                  : (d.frameWidth > 0 && d.frameHeight > 0
                      ? ((d.boxWidth / d.frameWidth) *
                              (d.boxHeight / d.frameHeight))
                          .clamp(0.0, 1.0)
                      : null),
            ),
        ],
      );
    } on MemoryTrackerException {
      // Best-effort silent logging; never block the walking loop.
    }
  }

  Future<void> _runSpatialAgent(
    List<GuideObjectSnapshot> snaps,
    List<RawDetection> raw,
  ) async {
    if (!_agentReady || !_streaming || _closing) {
      return;
    }
    final fusion = ref.read(spatialFusionProvider);
    final audio = ref.read(priorityAudioProvider);
    final nodes = ref.read(activeNodeStoreProvider);
    final db = ref.read(spatialDbProvider);
    final midas = _walk.fusedDepth?.midas;
    final depthMap = midas?.lastMap;

    final vectors = <SpatialVector>[];
    if (depthMap != null) {
      for (final snap in snaps) {
        final box = snap.boundingBox;
        if (box == null || snap.label.trim().isEmpty) {
          continue;
        }
        try {
          final vector = fusion.computeVector(
            label: snap.label,
            depthMap: depthMap,
            mapWidth: MonocularDepthEstimator.inputSize,
            mapHeight: MonocularDepthEstimator.inputSize,
            box: NormalizedBoundingBox(
              x1: box.left,
              y1: box.top,
              x2: box.right,
              y2: box.bottom,
            ),
          );
          vectors.add(vector);
        } on SpatialFusionException {
          continue;
        }
      }
    }

    for (final snap in snaps) {
      if (snap.confidence < 0.72) {
        continue;
      }
      try {
        final match = await db.resolveNode(snap.label);
        if (match != null) {
          await nodes.setActive(match.id);
          break;
        }
      } on SpatialDbException {
        break;
      }
    }

    if (vectors.isEmpty) {
      return;
    }
    final modes = ref.read(appModeControllerProvider);
    final now = DateTime.now();
    if (_lastPriorityAt != null &&
        now.difference(_lastPriorityAt!) < const Duration(milliseconds: 900)) {
      return;
    }

    SpatialVector? critical;
    for (final v in vectors) {
      final key = v.label.toLowerCase();
      final isCritical = _criticalLabels.contains(key) && v.depthZMeters <= 1.6;
      if (isCritical &&
          (critical == null || v.depthZMeters < critical.depthZMeters)) {
        critical = v;
      }
    }
    if (critical != null) {
      final allow = modes.allowHazardInterrupt(
        depthMetres: critical.depthZMeters,
        safetyCritical: true,
      );
      if (!allow) {
        return;
      }
      _lastPriorityAt = now;
      try {
        await audio.enqueue(
          PriorityUtterance(
            tier: AudioPriorityTier.critical,
            text: critical.summary,
            angleXDegrees: critical.angleXDegrees,
          ),
        );
        if (mounted) {
          setState(() {
            _status = critical!.summary;
            _alert = true;
          });
        }
      } on PriorityAudioException {
        // Priority path failed; legacy queue remains as backup.
      }
      return;
    }

    // Nav-vector chatter is hazard-nav only — never in TARGET_SEARCH.
    if (!modes.allowAmbientSceneSpeech) {
      return;
    }
    final nav = vectors.reduce(
      (a, b) => a.depthZMeters <= b.depthZMeters ? a : b,
    );
    if (nav.depthZMeters > 2.2) {
      return;
    }
    _lastPriorityAt = now;
    try {
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.navVector,
          text: nav.summary,
          angleXDegrees: nav.angleXDegrees,
        ),
      );
      if (mounted) {
        setState(() {
          _status = nav.summary;
          _alert = false;
        });
      }
    } on PriorityAudioCooldownSkip {
      // Expected spam guard.
    } on PriorityAudioException {
      // Keep walking without hard-failing the frame.
    }
  }

  Future<void> _toggleFollowMe() async {
    final imu = ref.read(imuTrackerProvider);
    final nodes = ref.read(activeNodeStoreProvider);
    final audio = ref.read(priorityAudioProvider);
    try {
      await ref.read(spatialAgentReadyProvider.future);
      if (_followMe) {
        await imu.cancelTeaching();
        await imu.stop();
        setState(() => _followMe = false);
        await audio.enqueue(
          const PriorityUtterance(
            tier: AudioPriorityTier.ambient,
            text: 'Follow Me cancelled.',
          ),
        );
        return;
      }
      final active = nodes.activeNodeId;
      if (active == null || active.isEmpty) {
        await audio.enqueue(
          const PriorityUtterance(
            tier: AudioPriorityTier.ambient,
            text:
                'Set your current place first. From home, say I am at my couch, then start Follow Me.',
          ),
        );
        return;
      }
      await imu.startTeaching(fromNodeId: active);
      setState(() => _followMe = true);
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.ambient,
          text:
              'Follow Me started from $active. Walk the path, then finish from voice home by naming the destination.',
        ),
      );
    } on ImuTrackerException catch (error) {
      await audio.enqueue(
        PriorityUtterance(
          tier: AudioPriorityTier.ambient,
          text: 'Follow Me failed: ${error.message}',
        ),
      );
    } on PriorityAudioException catch (error) {
      if (mounted) {
        setState(() => _status = error.message);
      }
    }
  }

  GuideObjectSnapshot? _bestTargetSnap(
    List<GuideObjectSnapshot> snaps,
    String target,
  ) {
    GuideObjectSnapshot? best;
    var bestScore = 0.0;
    final scoring = ObjectPriorityEngine(const GuideConfig());
    for (final s in snaps) {
      final m = scoring.targetMatch(s.label, target);
      if (m <= 0) {
        continue;
      }
      final closeness = s.distanceMeters == null
          ? s.boxProximity
          : (1.0 - (s.distanceMeters! / 4.0).clamp(0.0, 1.0));
      final score = m * 2 + closeness;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  bool _isGenericSceneLabel(String label) {
    return MemoryTracker.isAmbientNoise(label);
  }

  /// Rolling voice inventory — hazard-nav only; filters material noise.
  /// Rolling voice inventory — retained for future ambient mode re-enable.
  // ignore: unused_element
  void _maybeAnnounceScene(List<GuideObjectSnapshot> snaps) {
    final modes = ref.read(appModeControllerProvider);
    if (!modes.allowAmbientSceneSpeech || _alerts == null) {
      return;
    }
    if (_queue?.isPlaying ?? false) {
      return;
    }
    final named = snaps
        .where((s) => !_isGenericSceneLabel(s.label) && s.confidence >= 0.40)
        .toList();
    if (named.isEmpty) {
      return;
    }
    named.sort((a, b) {
      final scoreA = a.confidence * (0.35 + a.boxProximity);
      final scoreB = b.confidence * (0.35 + b.boxProximity);
      return scoreB.compareTo(scoreA);
    });
    final top = named.take(3).toList();
    final signature = top.map((s) => s.label.toLowerCase()).join('|');
    final now = DateTime.now();
    if (_lastSceneSignature == signature &&
        _lastSceneNarrationAt != null &&
        now.difference(_lastSceneNarrationAt!) < const Duration(seconds: 14)) {
      return;
    }
    if (_lastSceneNarrationAt != null &&
        now.difference(_lastSceneNarrationAt!) < const Duration(seconds: 7)) {
      return;
    }
    final line = _alerts!.speech.sceneInventory(top);
    if (line.isEmpty) {
      return;
    }
    _lastSceneSignature = signature;
    _lastSceneNarrationAt = now;
    if (mounted) {
      setState(() {
        _status = line;
        _alert = false;
      });
    }
    unawaited(
      _queue?.submit(
        GuideAnnouncement(
          spoken: line,
          decision: AnnouncementDecision.announce,
          band: PriorityBand.announce,
          priorityScore: 3,
          trackKey: 'scene-inventory',
          label: 'scene',
          speechPriority: SpeechPriority.medium,
        ),
      ),
    );
  }

  Future<void> _maybeGemini(List<RawDetection> objects) async {
    final fb = _geminiFallback;
    if (fb == null || !fb.shouldTrigger(objects)) {
      return;
    }
    final jpeg = await _yoloCtrl.capturePhoto(withOverlays: false);
    if (jpeg == null || jpeg.isEmpty) {
      return;
    }
    final line = await fb.identify(jpeg: jpeg, detections: objects);
    if (line == null || line.isEmpty || !_streaming || !mounted) {
      return;
    }
    if (mounted) {
      setState(() {
        _status = line;
        _alert = false;
      });
    }
    unawaited(
      _queue?.submit(
        GuideAnnouncement(
          spoken: line,
          decision: AnnouncementDecision.announce,
          band: PriorityBand.announce,
          priorityScore: 2,
          trackKey: 'gemini-fallback',
          label: 'scene',
          speechPriority: SpeechPriority.low,
        ),
      ),
    );
  }

  void _armStopPhrase() {
    if (_voiceLoop) {
      return;
    }
    _voiceLoop = true;
    Future<void>(() async {
      final stt = ref.read(speechToTextProvider);
      final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
      while (_streaming && mounted) {
        try {
          final spoken = await stt.listen(localeId: lang.sttLocale);
          if (!_streaming || !mounted) {
            return;
          }
          final lower = spoken.toLowerCase();
          if (RegExp(
            r'\b(stop guiding|stop walking|stop looking|go home|cancel)\b',
          ).hasMatch(lower)) {
            await _leave();
            return;
          }
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_streaming ||
        _controller == null ||
        _motionFrames.shouldSkip(busy: _busyFrame, nowMs: now)) {
      return;
    }
    _busyFrame = true;
    final latency = WalkingLatency()
      ..frameCapturedMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final input = inputImageFromCamera(
        image: image,
        camera: _controller!.description,
        deviceOrientation: _controller!.value.deviceOrientation,
      );
      if (input == null) {
        _badFrames += 1;
        if (_badFrames == 12 && mounted) {
          setState(() {
            _status = 'Camera frames are not readable. Restart Look ahead.';
            _alert = true;
          });
        }
        return;
      }
      _badFrames = 0;

      latency.inferenceStartedMs = DateTime.now().millisecondsSinceEpoch;
      final detector = _guideDetector;
      if (detector == null) {
        return;
      }
      var objects = await detector.detectInput(input);
      try {
        _lastNames = await _guideLabeler?.label(input) ?? const [];
      } catch (_) {}
      if (_lastNames.isNotEmpty) {
        final targetSearch = ref.read(appModeControllerProvider).isTargetSearch ||
            widget.findTarget.trim().isNotEmpty;
        objects = SceneLabeler.merge(
          objects,
          _lastNames,
          includeLabelOnly: targetSearch,
        );
      }
      latency.inferenceCompletedMs = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) {
        return;
      }
      await _ingestWalk(objects, fromYolo: false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Vision is starting. Keep the camera pointed ahead.';
        });
      }
    } finally {
      _busyFrame = false;
    }
  }

  Future<void> _quitApp() async {
    if (_closing) {
      return;
    }
    _closing = true;
    _taps.reset();
    await HapticFeedback.heavyImpact();
    await _stop();
    await ref.read(textToSpeechProvider).speak('Closing VisionAid. Goodbye.');
    await WakelockPlus.disable();
    SystemNavigator.pop();
  }

  Future<void> _emergencyFromWalk() async {
    if (_closing || _emergencyBusy) {
      return;
    }
    _emergencyBusy = true;
    await HapticFeedback.heavyImpact();
    try {
      final msg = await ref.read(emergencyServiceProvider).placeCall();
      if (mounted) {
        setState(() {
          _status = msg;
          _alert = true;
        });
      }
      await ref.read(textToSpeechProvider).speak(msg);
    } finally {
      _emergencyBusy = false;
    }
  }

  Future<void> _leave() async {
    ref.read(appModeControllerProvider).enterHazardNavigation();
    await _stop();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _stop() async {
    _streaming = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    await _yoloCtrl.stop();
    await _queue?.stop();
    await ref.read(textToSpeechProvider).stop();
    await ResearchMetrics.instance.persist();
    await _walk.fusedDepth?.dispose();
    await _releaseGuideMl();
  }

  Future<void> _releaseGuideMl() async {
    final detector = _guideDetector;
    final labeler = _guideLabeler;
    _guideDetector = null;
    _guideLabeler = null;
    await detector?.dispose();
    await labeler?.dispose();
    await _hazard.dispose();
    await _motionFrames.stop();
  }

  @override
  void dispose() {
    _taps.dispose();
    _streaming = false;
    unawaited(_motionFrames.stop());
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.dispose();
    }
    unawaited(_yoloCtrl.stop());
    unawaited(_queue?.stop());
    unawaited(_releaseGuideMl());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _controller;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Look ahead'),
        leading: IconButton(
          tooltip: 'Stop live vision',
          onPressed: _leave,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                    child: _starting
                        ? const Center(child: CircularProgressIndicator())
                        : _useYolo
                            ? YOLOView(
                                modelPath: _yoloModelPath,
                                task: YOLOTask.detect,
                                controller: _yoloCtrl,
                                confidenceThreshold: 0.22,
                                useGpu: true,
                                streamingConfig: const YOLOStreamingConfig(
                                  maxFPS: 18,
                                  inferenceFrequency: 18,
                                  includeMasks: false,
                                  includePoses: false,
                                  includeOBB: false,
                                  includeOriginalImage: false,
                                ),
                                onResult: _onYolo,
                                onModelLoad: _onYoloReady,
                                onModelError: _onYoloError,
                              )
                            : (preview == null || !preview.value.isInitialized
                                ? const Center(child: CircularProgressIndicator())
                                : CameraPreview(preview)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _alert ? const Color(0xFFFF8A80) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _toggleFollowMe,
                        child: Text(_followMe ? 'Cancel Follow Me' : 'Follow Me'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _leave,
                        child: const Text('Stop looking'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _twoFingers.down(event.pointer);
                if (_closing || _twoFingers.blocked) {
                  _taps.reset();
                  return;
                }
                _taps.tap();
              },
              onPointerUp: (event) => _twoFingers.up(event.pointer),
              onPointerCancel: (event) => _twoFingers.up(event.pointer),
            ),
          ),
        ],
      ),
    );
  }
}

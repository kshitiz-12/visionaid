import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../../core/providers/pipeline_providers.dart';
import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../../core/widgets/multi_tap_tracker.dart';
import '../../../../core/widgets/two_finger_down.dart';
import '../../../guide_alerts/data/guide_alert_engine.dart';
import '../../../guide_alerts/data/voice_announcement_queue.dart';
import '../../../guide_alerts/domain/guide_config.dart';
import '../../../guide_alerts/domain/guide_models.dart';
import '../../../walking/data/frame_throttle.dart';
import '../../../walking/data/hazard_cue.dart';
import '../../../walking/data/walking_latency.dart';
import '../../../walking/data/walking_pipeline.dart';
import '../../data/services/camera_image_converter.dart';
import '../../data/services/mlkit_object_detector.dart';
import '../../data/services/scene_labeler.dart';
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
  final _frames = FrameThrottle(minIntervalMs: 80);
  MlKitObjectDetector? _guideDetector;
  SceneLabeler? _guideLabeler;
  List<RawDetection> _lastNames = const [];
  late final MultiTapTracker _taps;
  late final TwoFingerDown _twoFingers;
  bool _emergencyBusy = false;
  bool _closing = false;
  bool _wasBlocked = false;
  int _clearFrames = 0;
  DateTime? _saidClearAt;
  bool _useYolo = true;
  final _yoloCtrl = YOLOViewController();
  YoloGeminiFallback? _geminiFallback;

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
    _alerts = GuideAlertEngine(
      config: const GuideConfig(),
      hindi: lang.code.toLowerCase().startsWith('hi'),
    );
    if (widget.findTarget.trim().isNotEmpty) {
      _alerts!.startTargetSearch(widget.findTarget);
    }
    _queue ??= VoiceAnnouncementQueue(tts);
    _geminiFallback ??= YoloGeminiFallback(ref.read(companionClientProvider));
    await _walk.warmup();

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
    setState(() {
      _starting = false;
      _status = lang.code.toLowerCase().startsWith('hi')
          ? 'आगे देखें.'
          : 'Look ahead.';
    });
    unawaited(tts.speak(_status));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_streaming && mounted) {
      _armStopPhrase();
    }
  }

  void _onYolo(List<YOLOResult> results) {
    if (!_streaming || _closing || !_useYolo) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_frames.shouldSkip(busy: _busyFrame, nowMs: now)) {
      return;
    }
    _busyFrame = true;
    unawaited(() async {
      try {
        await _ingestWalk(YoloMapper.toRaw(results), fromYolo: true);
      } finally {
        _busyFrame = false;
      }
    }());
  }

  Future<void> _onYoloReady(String path, YOLOTask? task) async {
    await _yoloCtrl.setShowOverlays(false);
    await _yoloCtrl.setConfidenceThreshold(0.25);
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
    final latency = WalkingLatency()
      ..frameCapturedMs = DateTime.now().millisecondsSinceEpoch
      ..inferenceCompletedMs = DateTime.now().millisecondsSinceEpoch;
    final tick = _walk.tick(raw: objects, latency: latency);
    final pathMetres = tick.snapshots
        .where((s) {
          final x = s.centerX ?? 0.5;
          return x >= 0.35 && x <= 0.65;
        })
        .map((s) => s.distanceMeters)
        .whereType<double>();
    await _hazard.pingIfWithinMetre(
      tick.occupancy.blocked
          ? tick.occupancy.closestMetres
          : (pathMetres.isEmpty
              ? null
              : pathMetres.reduce((a, b) => a < b ? a : b)),
    );
    if (fromYolo) {
      unawaited(_maybeGemini(objects));
    }
    // Decision + speech must not block the next YOLO/ML Kit frame.
    final mode = widget.findTarget.trim().isEmpty
        ? GuideMode.liveGuide
        : GuideMode.targetSearch;
    final result = _alerts!.evaluateSnapshots(
      snapshots: tick.snapshots,
      mode: mode,
      findTarget: widget.findTarget,
    );

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
      // Need a few clear frames so flicker does not say "Path clear."
      if (due && _clearFrames >= 4) {
        _wasBlocked = false;
        _clearFrames = 0;
        _saidClearAt = now;
        final clear = _alerts?.hindi == true ? 'रास्ता साफ़.' : 'Path clear.';
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

    if (result.announcements.isEmpty) {
      return;
    }
    final alert = result.announcements.first;
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
        _frames.shouldSkip(busy: _busyFrame, nowMs: now)) {
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
        objects = SceneLabeler.merge(objects, _lastNames);
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
  }

  @override
  void dispose() {
    _taps.dispose();
    _streaming = false;
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
                                modelPath: YoloObjectDetector.modelId(),
                                task: YOLOTask.detect,
                                controller: _yoloCtrl,
                                confidenceThreshold: 0.25,
                                useGpu: true,
                                streamingConfig: const YOLOStreamingConfig(
                                  maxFPS: 12,
                                  inferenceFrequency: 12,
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

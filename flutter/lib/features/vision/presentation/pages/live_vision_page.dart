import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  final _frames = FrameThrottle();
  MlKitObjectDetector? _guideDetector;
  SceneLabeler? _guideLabeler;
  List<RawDetection> _lastNames = const [];
  late final MultiTapTracker _taps;
  late final TwoFingerDown _twoFingers;
  bool _emergencyBusy = false;
  bool _closing = false;

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
    _alerts = GuideAlertEngine(
      config: const GuideConfig(),
    );
    if (widget.findTarget.trim().isNotEmpty) {
      _alerts!.startTargetSearch(widget.findTarget);
    }
    _queue ??= VoiceAnnouncementQueue(tts);
    _guideDetector ??= MlKitObjectDetector(stream: true);
    _guideLabeler ??= SceneLabeler();
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

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _starting = false;
        _status = 'No camera found.';
        _alert = true;
      });
      await tts.speak(_status);
      return;
    }

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    CameraController? controller;
    for (final preset in [
      ResolutionPreset.medium,
      ResolutionPreset.low,
      ResolutionPreset.high,
    ]) {
      try {
        await controller?.dispose();
        controller = CameraController(
          back,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.nv21,
        );
        await controller.initialize();
        break;
      } catch (_) {
        try {
          await controller?.dispose();
          controller = CameraController(
            back,
            preset,
            enableAudio: false,
          );
          await controller.initialize();
          break;
        } catch (_) {
          controller = null;
        }
      }
    }

    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _starting = false;
        _status = 'Camera failed to start. Try again.';
        _alert = true;
      });
      await tts.speak(_status);
      return;
    }

    try {
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {
        _starting = false;
        _status = 'Live. Point ahead. Two taps go home. Three taps emergency. Two fingers down to close.';
      });
      await tts.speak(_status);
      await controller.startImageStream(_onFrame);
      _streaming = true;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (_streaming && mounted) {
        _armStopPhrase();
      }
    } catch (_) {
      setState(() {
        _starting = false;
        _status = 'Camera failed to start. Try again.';
        _alert = true;
      });
      await tts.speak(_status);
    }
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

      final tick = _walk.tick(raw: objects, latency: latency);
      await _hazard.pingIfWithinMetre(
        tick.occupancy.closestMetres ??
            (tick.snapshots.isEmpty
                ? null
                : tick.snapshots
                    .map((s) => s.distanceMeters)
                    .whereType<double>()
                    .fold<double?>(
                      null,
                      (best, m) => best == null || m < best ? m : best,
                    )),
      );
      final mode = widget.findTarget.trim().isEmpty
          ? GuideMode.liveGuide
          : GuideMode.targetSearch;
      final result = _alerts!.evaluateSnapshots(
        snapshots: tick.snapshots,
        mode: mode,
        findTarget: widget.findTarget,
      );
      tick.latency.decisionCompletedMs = DateTime.now().millisecondsSinceEpoch;

      if (result.announcements.isEmpty) {
        return;
      }

      final alert = result.announcements.first;
      tick.latency.ttsTriggeredMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        setState(() {
          _status = alert.spoken;
          _alert = alert.safetyOverride ||
              alert.band == PriorityBand.critical ||
              alert.band == PriorityBand.highPriority;
        });
      }
      await _queue?.submit(alert);
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
                    child: _starting || preview == null || !preview.value.isInitialized
                        ? const Center(child: CircularProgressIndicator())
                        : CameraPreview(preview),
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

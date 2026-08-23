import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/pipeline_providers.dart';
import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../guide_alerts/data/guide_alert_engine.dart';
import '../../../guide_alerts/data/voice_announcement_queue.dart';
import '../../../guide_alerts/domain/guide_config.dart';
import '../../../guide_alerts/domain/guide_models.dart';
import '../../../walking/data/walking_latency.dart';
import '../../../walking/data/walking_pipeline.dart';
import '../../data/services/camera_image_converter.dart';

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
  String _debug = '';
  bool _research = false;
  bool _voiceLoop = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final tts = ref.read(textToSpeechProvider);
    _research = await UserPrefs.getResearchMode();
    _alerts = GuideAlertEngine(
      config: GuideConfig(debugMode: _research, researchLog: _research),
    );
    if (widget.findTarget.trim().isNotEmpty) {
      _alerts!.startTargetSearch(widget.findTarget);
    }
    _queue ??= VoiceAnnouncementQueue(tts);
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
        _status = 'Live. Point ahead.';
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
    if (_busyFrame || !_streaming || _controller == null) {
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
      final objects =
          await ref.read(objectDetectorProvider).detectInput(input);
      latency.inferenceCompletedMs = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) {
        return;
      }

      final tick = _walk.tick(raw: objects, latency: latency);
      final mode = widget.findTarget.trim().isEmpty
          ? GuideMode.liveGuide
          : GuideMode.targetSearch;
      final result = _alerts!.evaluateSnapshots(
        snapshots: tick.snapshots,
        mode: mode,
        findTarget: widget.findTarget,
      );
      tick.latency.decisionCompletedMs = DateTime.now().millisecondsSinceEpoch;

      if (_research) {
        final line = result.debugLines.isNotEmpty
            ? result.debugLines.first
            : tick.latency.debugLine(fps: tick.fps);
        _debug =
            '${tick.latency.debugLine(fps: tick.fps)}\n${_walk.depth.sourceId}\n$line';
      }

      if (result.announcements.isEmpty) {
        if (_research && mounted) {
          setState(() {});
        }
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
          if (_research) {
            _debug =
                '${tick.latency.debugLine(fps: tick.fps)}\n${alert.debugLine}';
          }
        });
      }
      ref.read(conversationMemoryProvider).rememberScene(alert.spoken);
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
  }

  @override
  void dispose() {
    _streaming = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live vision'),
        leading: IconButton(
          tooltip: 'Stop live vision',
          onPressed: _leave,
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _starting || preview == null || !preview.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : CameraPreview(preview),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _alert ? theme.colorScheme.error : Colors.white,
                    ),
                  ),
                  if (_research && _debug.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _debug,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _leave,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Stop looking'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

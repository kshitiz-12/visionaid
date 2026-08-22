import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/pipeline_providers.dart';
import '../../../../core/providers/voice_providers.dart';
import '../../../../core/utils/speak_gate.dart';
import '../../data/services/camera_image_converter.dart';
import '../../data/services/scene_labeler.dart';

/// Live camera + on-device detection. Speaks only hazards / scene changes.
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
  final _gate = SpeakGate();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final tts = ref.read(textToSpeechProvider);
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
    try {
      controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
    } catch (_) {
      await controller?.dispose();
      controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
    }

    try {
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {
        _starting = false;
        _status =
            'Live. Point the phone ahead. I will speak when something important is close.';
      });
      await tts.speak(_status);
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (error) {
      setState(() {
        _starting = false;
        _status = 'Camera failed to start. Try again.';
        _alert = true;
      });
      await tts.speak(_status);
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busyFrame || !_streaming || _controller == null) {
      return;
    }
    _busyFrame = true;
    try {
      final input = inputImageFromCamera(
        image: image,
        camera: _controller!.description,
        deviceOrientation: _controller!.value.deviceOrientation,
      );
      if (input == null) {
        return;
      }

      final objects =
          await ref.read(objectDetectorProvider).detectInput(input);
      final labels = await ref.read(sceneLabelerProvider).label(input);
      final detections = SceneLabeler.preferNamed(objects, labels);
      if (!mounted) {
        return;
      }

      final decision = ref.read(contextEngineProvider).evaluate(
            detections: detections.map((d) => d.toMap()).toList(),
            intentTarget: widget.findTarget,
          );

      final hazard = decision.reason == 'hazard';
      if (!decision.shouldSpeak) {
        return;
      }
      if (!_gate.allow(decision.spokenMessage, hazard: hazard)) {
        return;
      }

      setState(() {
        _status = decision.spokenMessage;
        _alert = hazard;
      });
      ref.read(conversationMemoryProvider).rememberScene(decision.spokenMessage);
      await ref.read(textToSpeechProvider).speak(decision.spokenMessage);
    } catch (_) {
      // Drop a bad frame; keep the stream alive.
    } finally {
      _busyFrame = false;
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
          onPressed: () async {
            await _stop();
            if (context.mounted) {
              context.go('/home');
            }
          },
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
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _stop();
                      if (context.mounted) {
                        context.go('/home');
                      }
                    },
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

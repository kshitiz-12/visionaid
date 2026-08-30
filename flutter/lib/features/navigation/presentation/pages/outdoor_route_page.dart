import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/research_metrics.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../../core/widgets/multi_tap_tracker.dart';
import '../../../../core/widgets/two_finger_down.dart';
import '../../data/outdoor_directions_service.dart';

/// Voice-first outdoor walking directions (Google Directions API).
class OutdoorRoutePage extends ConsumerStatefulWidget {
  const OutdoorRoutePage({super.key, required this.destination});

  final String destination;

  @override
  ConsumerState<OutdoorRoutePage> createState() => _OutdoorRoutePageState();
}

class _OutdoorRoutePageState extends ConsumerState<OutdoorRoutePage> {
  final _directions = OutdoorDirectionsService();
  OutdoorRoute? _route;
  int _stepIndex = 0;
  String _status = 'Planning route…';
  bool _alert = false;
  bool _closing = false;
  StreamSubscription<Position>? _posSub;
  late final MultiTapTracker _taps;
  late final TwoFingerDown _twoFingers;
  bool _hindi = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    ResearchMetrics.instance.startSession(label: 'outdoor');
    _taps = MultiTapTracker(
      onSingle: () {},
      onDouble: () => unawaited(_leave()),
      onTriple: () {},
    );
    _twoFingers = TwoFingerDown(onTwo: () => unawaited(_quit()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final tts = ref.read(textToSpeechProvider);
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    _hindi = lang.code.toLowerCase().startsWith('hi');

    if (!OutdoorDirectionsService.isConfigured) {
      setState(() {
        _status = _hindi
            ? 'आउटडोर नेविगेशन के लिए GEOAPIFY_API_KEY जोड़ें.'
            : 'Add GEOAPIFY_API_KEY in .env for outdoor navigation.';
        _alert = true;
      });
      await tts.speak(_status);
      return;
    }

    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) {
      setState(() {
        _status = _hindi
            ? 'लोकेशन अनुमति चाहिए.'
            : 'Location permission is required.';
        _alert = true;
      });
      await tts.speak(_status);
      return;
    }

    try {
      final route = await _directions.planWalkingRoute(
        destinationQuery: widget.destination,
        hindi: _hindi,
      );
      if (!mounted) {
        return;
      }
      _route = route;
      final km = (route.totalMetres / 1000).toStringAsFixed(1);
      setState(() {
        _status = _hindi
            ? '${widget.destination} तक लगभग $km किमी. चलना शुरू करें.'
            : 'Route to ${widget.destination}, about $km km. Start walking.';
      });
      await tts.speak(_status);
      ResearchMetrics.instance.log('route_ready', {
        'destination': widget.destination,
        'metres': route.totalMetres,
        'steps': route.steps.length,
      });
      if (route.steps.isNotEmpty) {
        await _speakStep(0);
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 4,
        ),
      ).listen(_onPosition);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.toString().replaceFirst('Bad state: ', '');
        _alert = true;
      });
      await tts.speak(_status);
    }
  }

  Future<void> _speakStep(int index) async {
    final route = _route;
    if (route == null || index < 0 || index >= route.steps.length) {
      return;
    }
    final line = _directions.speakStep(route.steps[index], hindi: _hindi);
    setState(() {
      _status = line;
      _stepIndex = index;
    });
    ResearchMetrics.instance.logAnnouncement(
      spoken: line,
      label: 'route-step',
      safety: false,
    );
    await ref.read(textToSpeechProvider).speak(line);
  }

  void _onPosition(Position pos) {
    final route = _route;
    if (route == null || _closing || _stepIndex >= route.steps.length) {
      return;
    }
    final step = route.steps[_stepIndex];
    final dist = OutdoorDirectionsService.metresBetween(
      pos.latitude,
      pos.longitude,
      step.endLat,
      step.endLng,
    );
    if (dist <= 18) {
      final next = _stepIndex + 1;
      if (next >= route.steps.length) {
        unawaited(_arrived());
      } else {
        unawaited(_speakStep(next));
      }
    }
  }

  Future<void> _arrived() async {
    final line = _hindi
        ? 'आप पहुँच गए. ${widget.destination}.'
        : 'You have arrived at ${widget.destination}.';
    setState(() {
      _status = line;
      _alert = false;
    });
    ResearchMetrics.instance.log('arrived', {'destination': widget.destination});
    await ref.read(textToSpeechProvider).speak(line);
    await ResearchMetrics.instance.persist();
  }

  Future<void> _leave() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _posSub?.cancel();
    await ResearchMetrics.instance.persist();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _quit() async {
    await _posSub?.cancel();
    await SystemNavigator.pop();
  }

  @override
  void dispose() {
    _taps.dispose();
    unawaited(_posSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Outdoor route'),
        leading: IconButton(
          onPressed: _leave,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.destination,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _alert ? const Color(0xFFFF8A80) : Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _hindi
                        ? 'दो टैप: होम. कर्ब जोखिम के लिए Look ahead खोलें.'
                        : 'Double tap: home. Open Look ahead for curb hazards.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _leave,
                    child: Text(_hindi ? 'रोकें' : 'Stop route'),
                  ),
                ],
              ),
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

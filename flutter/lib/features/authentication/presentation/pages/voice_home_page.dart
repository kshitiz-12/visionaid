import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/pipeline_providers.dart';
import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/sentence_speech_queue.dart';
import '../../../../core/services/spoken_confirm.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../../core/widgets/multi_tap_tracker.dart';
import '../../../../core/widgets/two_finger_down.dart';
import '../../../communication/domain/contact_matcher.dart';
import '../../../intent/domain/entities/user_intent.dart';
import '../../../voice/presentation/widgets/voice_command_button.dart';
import '../../../voice/presentation/widgets/voice_status_banner.dart';

enum _Dialog { idle, needName, needPick, needBody, needConfirm }

class VoiceHomePage extends ConsumerStatefulWidget {
  const VoiceHomePage({super.key});

  @override
  ConsumerState<VoiceHomePage> createState() => _VoiceHomePageState();
}

class _VoiceHomePageState extends ConsumerState<VoiceHomePage>
    with WidgetsBindingObserver {
  String _status = 'Tap the mic and speak.';
  bool _isAlert = false;
  bool _listening = false;
  bool _busy = false;
  _Dialog _dialog = _Dialog.idle;
  CommAction _channel = CommAction.call;
  String _queryName = '';
  String _body = '';
  List<PhoneContact> _picks = [];
  PhoneContact? _chosen;
  bool _awaitingReturn = false;
  late final MultiTapTracker _taps;
  late final TwoFingerDown _twoFingers;
  bool _closing = false;
  SentenceSpeechQueue? _speechQ;

  SentenceSpeechQueue get _sentences =>
      _speechQ ??= SentenceSpeechQueue(ref.read(textToSpeechProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _taps = MultiTapTracker(
      onSingle: () {
        if (!_busy) {
          unawaited(_listenAndHandle());
        }
      },
      onDouble: () {
        if (!_busy) {
          unawaited(_openLookAhead());
        }
      },
      onTriple: () {
        unawaited(HapticFeedback.heavyImpact());
        unawaited(_runQuick('Emergency'));
      },
    );
    _twoFingers = TwoFingerDown(onTwo: () {
      unawaited(_quit());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  @override
  void dispose() {
    _taps.dispose();
    unawaited(_speechQ?.stop());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    WakelockPlus.enable();
    if (_awaitingReturn && mounted) {
      _awaitingReturn = false;
      _say("You're back in VisionAid. Tap the mic when you are ready.");
    }
  }

  Future<void> _welcome() async {
    unawaited(ref.read(companionClientProvider).wake());
    await _ensureCorePermissions();
    final prefs = await SharedPreferences.getInstance();
    final heard = prefs.getBool('visionaid_welcome_spoken') ?? false;
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    final name = await UserPrefs.getName();
    await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);

    final message = lang.code == 'hi'
        ? (heard
            ? 'VisionAid तैयार है। एक टैप बोलो। दो टैप आगे देखो। तीन टैप इमरजेंसी। दो उंगली नीचे से ऐप बंद।'
            : 'नमस्ते${name.isEmpty ? '' : ' $name'}. एक टैप बोलो। दो टैप गाइड। तीन टैप इमरजेंसी। दो उंगली नीचे से बंद।')
        : (heard
            ? 'VisionAid is ready. One tap to speak. Two taps look ahead. Three taps emergency. Two fingers down to close.'
            : 'Hello${name.isEmpty ? '' : ' $name'}. One tap to speak, two for look ahead, three for emergency. Two fingers down to close.');

    if (!mounted) {
      return;
    }
    setState(() => _status = message);
    await ref.read(textToSpeechProvider).speak(message, natural: true);
    await prefs.setBool('visionaid_welcome_spoken', true);
  }

  Future<void> _ensureCorePermissions() async {
    await FlutterContacts.permissions.request(PermissionType.read);
    await Permission.microphone.request();
    await Permission.phone.request();
  }

  Future<void> _openLookAhead() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) {
      return;
    }
    context.push('/live');
  }

  void _resetDialog() {
    _dialog = _Dialog.idle;
    _channel = CommAction.call;
    _queryName = '';
    _body = '';
    _picks = [];
    _chosen = null;
  }

  Future<void> _quit() async {
    if (_closing) {
      return;
    }
    _closing = true;
    _taps.reset();
    await HapticFeedback.heavyImpact();
    await ref.read(textToSpeechProvider).speak('Closing VisionAid. Goodbye.');
    await WakelockPlus.disable();
    SystemNavigator.pop();
  }

  Future<void> _say(String message, {bool alert = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = message;
      _isAlert = alert;
    });
    await ref.read(textToSpeechProvider).speak(message, natural: !alert);
  }

  Future<void> _listenAndHandle() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _listening = true;
      _isAlert = false;
      _status = 'Listening… speak now.';
    });

    final tts = ref.read(textToSpeechProvider);
    final stt = ref.read(speechToTextProvider);
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());

    try {
      await _sentences.stop();
      await tts.stop();
      unawaited(ref.read(companionClientProvider).wake());
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final spoken = await stt.listen(localeId: lang.sttLocale);
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
        _status = 'Heard: $spoken';
      });
      await _handleSpoken(spoken);
    } catch (error) {
      await _say(error.toString().replaceFirst('Bad state: ', ''), alert: true);
    } finally {
      if (mounted) {
        setState(() {
          _listening = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _runQuick(String spokenText) async {
    final emergency = spokenText.toLowerCase() == 'emergency';
    if (_busy && !emergency) {
      return;
    }
    setState(() {
      _busy = true;
      _listening = false;
    });
    try {
      await ref.read(textToSpeechProvider).stop();
      await _sentences.stop();
      await _handleSpoken(spokenText);
    } catch (error) {
      await _say(error.toString().replaceFirst('Bad state: ', ''), alert: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _channelLabel() {
    return switch (_channel) {
      CommAction.whatsapp => 'WhatsApp',
      CommAction.sms => 'SMS',
      _ => 'call',
    };
  }

  Future<bool> _bindContact(String name) async {
    final lookup = await ref.read(emergencyServiceProvider).lookup(name);
    if (lookup.permissionDenied) {
      await _say(
        'I need contacts permission to find people. Enable Contacts in settings.',
        alert: true,
      );
      await openAppSettings();
      return false;
    }
    if (lookup.matches.isEmpty) {
      await _say(
        'I could not find $name in your phone contacts. Save the number on this phone, then try again.',
        alert: true,
      );
      return false;
    }
    if (lookup.matches.length == 1) {
      _chosen = lookup.matches.first;
      return true;
    }
    _picks = lookup.matches;
    _dialog = _Dialog.needPick;
    final listed = [
      for (var i = 0; i < _picks.length; i++) '${i + 1}: ${_picks[i].displayName}',
    ].join('. ');
    await _say('I found ${_picks.length} matches. $listed. Say 1, 2, or 3.');
    return false;
  }

  Future<void> _dispatchMessage() async {
    final contact = _chosen;
    if (contact == null) {
      await _say('No contact selected.');
      _resetDialog();
      return;
    }
    final comm = ref.read(emergencyServiceProvider);
    final result = _channel == CommAction.whatsapp
        ? await comm.whatsappContact(contact, _body)
        : await comm.smsContact(contact, _body);
    _resetDialog();
    _awaitingReturn = true;
    await _say(result);
  }

  Future<void> _dispatchCall() async {
    final contact = _chosen;
    if (contact == null) {
      await _say('No contact selected.');
      _resetDialog();
      return;
    }
    final result = await ref.read(emergencyServiceProvider).callContact(contact);
    _resetDialog();
    _awaitingReturn = true;
    await _say(result);
  }

  Future<void> _startMessageFlow(UserIntent intent) async {
    _channel = intent.commAction;
    _queryName = intent.contactName;
    if (_queryName.isEmpty) {
      _dialog = _Dialog.needName;
      await _say('Who should I ${_channelLabel()}? Say the name.');
      return;
    }
    final ok = await _bindContact(_queryName);
    if (!ok) {
      return;
    }
    if (intent.messageBody.isNotEmpty) {
      _body = intent.messageBody;
      _dialog = _Dialog.needConfirm;
      await _say(
        'Send this ${_channelLabel()} to ${_chosen!.displayName}: $_body. Say yes or no.',
      );
      return;
    }
    _dialog = _Dialog.needBody;
    await _say('What should I say to ${_chosen!.displayName} on ${_channelLabel()}?');
  }

  Future<void> _startCallFlow(UserIntent intent) async {
    _channel = CommAction.call;
    _queryName = intent.contactName;
    if (_queryName.isEmpty) {
      _dialog = _Dialog.needName;
      await _say('Who should I call? Say the name.');
      return;
    }
    final ok = await _bindContact(_queryName);
    if (!ok) {
      return;
    }
    await _dispatchCall();
  }

  Future<void> _handleSpoken(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      await _say("I didn't catch that. Tap once and try again.");
      return;
    }

    final intent = await ref.read(intentEngineProvider).classify(spokenText);

    if (intent.type == IntentType.quit) {
      await _quit();
      return;
    }

    if (intent.type == IntentType.cancel) {
      _resetDialog();
      await _say('Okay, cancelled.');
      return;
    }

    if (_dialog == _Dialog.needName) {
      _queryName = spokenText.trim();
      if (_channel == CommAction.call) {
        final ok = await _bindContact(_queryName);
        if (ok) {
          await _dispatchCall();
        }
      } else {
        final ok = await _bindContact(_queryName);
        if (ok) {
          _dialog = _Dialog.needBody;
          await _say('What should I say to ${_chosen!.displayName}?');
        }
      }
      return;
    }

    if (_dialog == _Dialog.needPick) {
      final index = SpokenConfirm.choiceIndex(spokenText, _picks.length);
      if (index == null) {
        await _say('Please say 1 or 2 to pick the contact.');
        return;
      }
      _chosen = _picks[index];
      if (_channel == CommAction.call) {
        await _dispatchCall();
      } else {
        _dialog = _Dialog.needBody;
        await _say('What should I say to ${_chosen!.displayName}?');
      }
      return;
    }

    if (_dialog == _Dialog.needBody) {
      _body = spokenText.trim();
      if (_body.isEmpty) {
        await _say('I did not catch the message. Please say it again.');
        return;
      }
      _dialog = _Dialog.needConfirm;
      await _say(
        'Send this ${_channelLabel()} to ${_chosen?.displayName ?? _queryName}: $_body. Say yes or no.',
      );
      return;
    }

    if (_dialog == _Dialog.needConfirm) {
      if (SpokenConfirm.isYes(spokenText)) {
        await _dispatchMessage();
      } else if (SpokenConfirm.isNo(spokenText)) {
        _resetDialog();
        await _say('Okay, cancelled.');
      } else {
        await _say('Please say yes to send, or no to cancel.');
      }
      return;
    }

    if (intent.type == IntentType.emergency) {
      final result = await ref.read(emergencyServiceProvider).placeCall(
            contactName: intent.contactName,
          );
      await _say(result, alert: true);
      return;
    }

    if (intent.type == IntentType.communication) {
      if (intent.commAction == CommAction.sms ||
          intent.commAction == CommAction.whatsapp) {
        await _startMessageFlow(intent);
        return;
      }
      await _startCallFlow(intent);
      return;
    }

    final liveGuide = intent.type == IntentType.navigation ||
        intent.type == IntentType.findObject;

    if (intent.type == IntentType.routeNavigate) {
      if (!mounted) {
        return;
      }
      final dest = intent.target.trim();
      if (dest.isEmpty) {
        await _say('Where should I take you? Say navigate to the park.');
        return;
      }
      context.push('/route?dest=${Uri.encodeQueryComponent(dest)}');
      return;
    }

    if (liveGuide) {
      if (!mounted) {
        return;
      }
      if (intent.type == IntentType.findObject &&
          intent.target.trim().isEmpty) {
        await _say('What should I look for? Say find my purse, or find the chair.');
        return;
      }
      final target = Uri.encodeQueryComponent(intent.target.trim());
      final path = target.isEmpty ? '/live' : '/live?target=$target';
      context.push(path);
      return;
    }

    var preview = '';
    var streamed = false;
    final result = await ref.read(assistantPipelineProvider).handleSpoken(
          spokenText,
          onSentence: (sentence) {
            if (sentence.trim().isEmpty || !mounted) {
              return;
            }
            streamed = true;
            preview = preview.isEmpty ? sentence : '$preview $sentence';
            setState(() {
              _status = preview;
              _isAlert = false;
            });
            _sentences.enqueue(sentence);
          },
        );
    await _sentences.waitIdle();
    final reply = result.spokenReply.trim();
    if (reply.isEmpty) {
      return;
    }
    final covered = streamed && _streamCoveredReply(preview, reply);
    if (!covered) {
      if (streamed) {
        await _sentences.stop();
      }
      await _say(
        reply,
        alert: result.isAlert || result.intent.type == IntentType.emergency,
      );
    } else if (mounted && reply != preview) {
      setState(() {
        _status = reply;
        _isAlert = result.isAlert;
      });
    }
  }

  bool _streamCoveredReply(String preview, String reply) {
    final p = preview.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final r = reply.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (p.isEmpty) {
      return false;
    }
    if (r.startsWith(p) || p.startsWith(r)) {
      return true;
    }
    return p.length >= (r.length * 0.7).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _say(
          'Two fingers down on the screen to close VisionAid. The back button will not close the app.',
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VisionAid'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: _busy ? null : () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _twoFingers.down(event.pointer),
            onPointerUp: (event) => _twoFingers.up(event.pointer),
            onPointerCancel: (event) => _twoFingers.up(event.pointer),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_closing || _twoFingers.blocked) {
                  return;
                }
                _taps.tap();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tap once to speak. Twice look ahead. Three times emergency. Two fingers down to close.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Semantics(
                          button: true,
                          label:
                              'Tap anywhere once to speak. Twice for look ahead. Three times for emergency. Two fingers down to close.',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 196,
                            height: 196,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _listening
                                    ? [
                                        theme.colorScheme.error,
                                        theme.colorScheme.error.withValues(alpha: 0.75),
                                      ]
                                    : (_busy
                                        ? [
                                            theme.colorScheme.tertiary,
                                            theme.colorScheme.primary,
                                          ]
                                        : [
                                            theme.colorScheme.primary,
                                            const Color(0xFF1D4ED8),
                                          ]),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_listening
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _listening
                                  ? Icons.hearing
                                  : (_busy ? Icons.hourglass_top : Icons.mic),
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _listening
                          ? 'Listening…'
                          : (_busy ? 'Working…' : 'Tap anywhere to speak'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    VoiceStatusBanner(message: _status, isAlert: _isAlert),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: VoiceCommandButton(
                            label: 'Look ahead',
                            tonal: true,
                            onPressed: _busy
                                ? () {}
                                : () => unawaited(_openLookAhead()),
                            icon: Icons.visibility_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: VoiceCommandButton(
                            label: 'Emergency',
                            danger: true,
                            onPressed: () => unawaited(_runQuick('Emergency')),
                            icon: Icons.warning_amber_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

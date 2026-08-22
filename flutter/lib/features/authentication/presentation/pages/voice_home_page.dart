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
import '../../../../core/services/spoken_confirm.dart';
import '../../../../core/services/user_prefs.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  @override
  void dispose() {
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
    await _ensureCorePermissions();
    final prefs = await SharedPreferences.getInstance();
    final heard = prefs.getBool('visionaid_welcome_spoken') ?? false;
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    final name = await UserPrefs.getName();
    await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);

    final message = lang.code == 'hi'
        ? (heard
            ? 'VisionAid तैयार है। मुझसे कुछ भी पूछो, प्लान करो, कॉल करो, या गाइड मी कहो। बंद करने के लिए क्विट कहो।'
            : 'नमस्ते${name.isEmpty ? '' : ' $name'}. मैं साथ हूँ। सवाल पूछो, कॉल करो, या गाइड मी कहो।')
        : (heard
            ? 'VisionAid is ready. Ask me anything, plan something, call a name, or say guide me. Say quit to close.'
            : 'Hello${name.isEmpty ? '' : ' $name'}. I am right here with you. Ask me anything, '
                'say call a name, or say guide me to walk with you.');

    if (!mounted) {
      return;
    }
    setState(() => _status = message);
    await ref.read(textToSpeechProvider).speak(message);
    await prefs.setBool('visionaid_welcome_spoken', true);
  }

  Future<void> _ensureCorePermissions() async {
    await FlutterContacts.permissions.request(PermissionType.read);
    await Permission.microphone.request();
    await Permission.phone.request();
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
    await ref.read(textToSpeechProvider).speak(message);
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
      await tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 350));
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
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _listening = false;
    });
    try {
      await ref.read(textToSpeechProvider).stop();
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

    if (intent.type == IntentType.communication) {
      if (intent.commAction == CommAction.sms ||
          intent.commAction == CommAction.whatsapp) {
        await _startMessageFlow(intent);
        return;
      }
      await _startCallFlow(intent);
      return;
    }

    final liveGuide = intent.type == IntentType.navigation;

    if (liveGuide) {
      if (!mounted) {
        return;
      }
      final target = Uri.encodeQueryComponent(intent.target);
      context.push('/live?target=$target');
      return;
    }

    final result =
        await ref.read(assistantPipelineProvider).handleSpoken(spokenText);
    await _say(
      result.spokenReply,
      alert: result.isAlert || result.intent.type == IntentType.emergency,
    );
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
          'Say quit to close VisionAid. The back button will not close the app.',
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VisionAid++'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: _busy ? null : () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Microphone. Double tap and speak.',
                      child: InkWell(
                        onTap: _busy ? null : _listenAndHandle,
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 96,
                          backgroundColor: _listening
                              ? theme.colorScheme.error
                              : (_busy
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.primary),
                          child: Icon(
                            _listening
                                ? Icons.hearing
                                : (_busy ? Icons.hourglass_top : Icons.mic),
                            size: 88,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  _listening
                      ? 'Listening…'
                      : (_busy ? 'Working…' : 'Speak. I stay on this screen.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                VoiceStatusBanner(message: _status, isAlert: _isAlert),
                const SizedBox(height: 16),
                VoiceCommandButton(
                  label: 'Speak',
                  onPressed: _busy ? () {} : _listenAndHandle,
                  icon: Icons.mic,
                ),
                const SizedBox(height: 12),
                VoiceCommandButton(
                  label: 'Look ahead',
                  onPressed: _busy ? () {} : () => context.push('/live'),
                  icon: Icons.visibility_outlined,
                ),
                const SizedBox(height: 12),
                VoiceCommandButton(
                  label: 'Emergency',
                  onPressed: _busy ? () {} : () => _runQuick('Emergency'),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

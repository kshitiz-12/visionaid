import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';
import '../../../../features/voice/presentation/providers/voice_provider.dart';
import '../../../../features/voice/presentation/widgets/voice_command_button.dart';
import '../../../../features/voice/presentation/widgets/voice_status_banner.dart';

class VoiceHomePage extends ConsumerStatefulWidget {
  const VoiceHomePage({super.key});

  @override
  ConsumerState<VoiceHomePage> createState() => _VoiceHomePageState();
}

class _VoiceHomePageState extends ConsumerState<VoiceHomePage> {
  String _status = 'Tap the mic and speak.';
  bool _isAlert = false;
  bool _listening = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  Future<void> _welcome() async {
    final prefs = await SharedPreferences.getInstance();
    final heard = prefs.getBool('visionaid_welcome_spoken') ?? false;
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    final name = await UserPrefs.getName();
    await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);

    final message = lang.code == 'hi'
        ? (heard
            ? 'VisionAid तैयार है। मैं आपकी कैसे मदद कर सकता हूँ?'
            : 'नमस्ते${name.isEmpty ? '' : ' $name'}. VisionAid तैयार है। माइक दबाकर बोलें।')
        : (heard
            ? 'VisionAid is ready. How can I help?'
            : 'Hello${name.isEmpty ? '' : ' $name'}. VisionAid is ready. Tap the mic and speak.');

    setState(() => _status = message);
    await ref.read(textToSpeechProvider).speak(message);
    await prefs.setBool('visionaid_welcome_spoken', true);
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
    await tts.stop();
    await tts.speak('Listening.');

    try {
      final spoken = await ref.read(speechToTextProvider).listen();
      await _handleSpoken(spoken);
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        _status = message;
        _isAlert = true;
      });
      await tts.speak(message);
    } finally {
      if (mounted) {
        setState(() {
          _listening = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleSpoken(String spokenText) async {
    final tts = ref.read(textToSpeechProvider);
    final command =
        await ref.read(voiceRepositoryProvider).classifyCommand(spokenText);
    final voiceContext = await ref
        .read(voiceRepositoryProvider)
        .buildContext(spokenText: spokenText);

    await ref.read(voiceCommandProvider.notifier).parse(spokenText);
    await ref.read(voiceContextProvider.notifier).buildContext(spokenText);

    final reply = switch (command.intent) {
      'emergency' =>
        'Emergency mode. Stay calm. I will help you get assistance.',
      'navigation' =>
        'Navigation. I heard: $spokenText. Camera guidance is coming next.',
      'ocr' || 'read' =>
        'Reading mode. Point the camera at text and I will read it aloud soon.',
      'help' =>
        'You can say: what is in front of me, navigate, read text, or emergency.',
      _ =>
        'I heard: $spokenText. Intent ${command.intent}. '
            'Environment ${voiceContext.environment}.',
    };

    setState(() {
      _status = reply;
      _isAlert = command.intent == 'emergency';
    });
    await tts.speak(reply);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VisionAid++'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
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
                    label: 'Microphone. Double tap and speak your command.',
                    child: InkWell(
                      onTap: _busy ? null : _listenAndHandle,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 96,
                        backgroundColor: _listening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        child: Icon(
                          _listening ? Icons.hearing : Icons.mic,
                          size: 88,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                _listening ? 'Listening…' : 'Tap mic and speak',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'No account needed. Just speak.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              VoiceStatusBanner(message: _status, isAlert: _isAlert),
              const SizedBox(height: 16),
              VoiceCommandButton(
                label: _listening ? 'Listening…' : 'Speak command',
                onPressed: _busy ? () {} : _listenAndHandle,
                icon: Icons.record_voice_over_rounded,
              ),
              const SizedBox(height: 12),
              VoiceCommandButton(
                label: 'Emergency',
                onPressed: _busy
                    ? () {}
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await _handleSpoken('Emergency');
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                          }
                        }
                      },
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

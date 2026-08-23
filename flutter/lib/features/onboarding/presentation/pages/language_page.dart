import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/spoken_confirm.dart';
import '../../../../core/services/user_prefs.dart';

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  bool _busy = false;
  String _status = 'Welcome to VisionAid. Say English or Hindi.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptAndListen());
  }

  Future<void> _promptAndListen() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final tts = ref.read(textToSpeechProvider);
    final stt = ref.read(speechToTextProvider);

    try {
      await Permission.microphone.request();
      await tts.setLocale('en-US');
      await tts.speak(
        'Welcome to VisionAid. Which language do you prefer? '
        'Say English, or say Hindi.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Listening… say English or Hindi.');
      final spoken = await stt.listen(localeId: 'en_US');
      final code = SpokenConfirm.parseLanguage(spoken);
      if (code == null) {
        setState(() => _status = 'I heard: $spoken. Please say English or Hindi.');
        await tts.speak('I heard $spoken. Please say English or Hindi.');
        return;
      }
      await _select(AppLanguage.fromCode(code));
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      if (mounted) {
        setState(() => _status = message);
      }
      await tts.speak('$message Tap the button and say English or Hindi.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _select(AppLanguage language) async {
    await UserPrefs.setLanguageCode(language.code);
    await ref.read(textToSpeechProvider).setLocale(language.ttsLocale);

    final confirm = language.code == 'hi'
        ? 'हिंदी चुनी गई। अब अपना नाम बोलें।'
        : 'English selected. Next, say your name.';

    setState(() => _status = confirm);
    await ref.read(textToSpeechProvider).speak(confirm);
    if (mounted) {
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to VisionAid',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _promptAndListen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                ),
                child: Text(_busy ? 'Listening…' : 'Speak language'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _select(AppLanguage.english),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('English'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _select(AppLanguage.hindi),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Hindi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

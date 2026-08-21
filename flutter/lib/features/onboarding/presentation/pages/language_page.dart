import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(textToSpeechProvider).setLocale('en-US');
      await ref.read(textToSpeechProvider).speak(
            'Welcome to VisionAid. Which language do you prefer? '
            'Choose English or Hindi.',
          );
    });
  }

  Future<void> _select(AppLanguage language) async {
    await UserPrefs.setLanguageCode(language.code);
    await ref.read(textToSpeechProvider).setLocale(language.ttsLocale);

    final confirm = language.code == 'hi'
        ? 'हिंदी चुनी गई। अब अपना प्रोफ़ाइल सेट करें।'
        : 'English selected. Next, set up your profile.';

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
              const SizedBox(height: 12),
              Text(
                'Which language do you prefer?',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ...AppLanguage.supported.map((language) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    button: true,
                    label: 'Select ${language.label}',
                    child: FilledButton(
                      onPressed: () => _select(language),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                      ),
                      child: Text(
                        language.label,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

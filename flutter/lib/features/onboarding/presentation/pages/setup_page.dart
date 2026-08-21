import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _nameController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
      await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);
      final prompt = lang.code == 'hi'
          ? 'अपना नाम और आपातकालीन संपर्क दर्ज करें।'
          : 'Please enter your name and an emergency contact number.';
      await ref.read(textToSpeechProvider).speak(prompt);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      await ref.read(textToSpeechProvider).speak(
            'Please fill your name and emergency contact.',
          );
      return;
    }

    setState(() => _saving = true);
    await UserPrefs.setName(_nameController.text);
    await UserPrefs.setEmergencyContact(_emergencyController.text);
    await UserPrefs.setSetupComplete(true);

    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    final done = lang.code == 'hi'
        ? 'सेटअप पूरा। VisionAid तैयार है।'
        : 'Setup complete. VisionAid is ready. How can I help?';

    await ref.read(textToSpeechProvider).speak(done);
    if (mounted) {
      setState(() => _saving = false);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile setup')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Simple setup',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Saved only on this phone. No login.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact phone',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 8) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(_saving ? 'Saving…' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

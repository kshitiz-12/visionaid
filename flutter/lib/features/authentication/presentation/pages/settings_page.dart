import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/user_prefs.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _nameController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyController = TextEditingController();
  double _voiceSpeed = 0.45;
  String _languageCode = 'en';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emergencyNameController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _nameController.text = await UserPrefs.getName();
    _emergencyNameController.text = await UserPrefs.getEmergencyContactName();
    _emergencyController.text = await UserPrefs.getEmergencyContact();
    _voiceSpeed = await UserPrefs.getVoiceSpeed();
    _languageCode = await UserPrefs.getLanguageCode();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await UserPrefs.setName(_nameController.text);
    await UserPrefs.setEmergencyContactName(_emergencyNameController.text);
    await UserPrefs.setEmergencyContact(_emergencyController.text);
    await UserPrefs.setVoiceSpeed(_voiceSpeed);
    await UserPrefs.setLanguageCode(_languageCode);
    final lang = AppLanguage.fromCode(_languageCode);
    await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);
    await ref.read(textToSpeechProvider).speak(
          _languageCode == 'hi' ? 'सेटिंग्स सेव हो गईं।' : 'Settings saved.',
        );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device')),
      );
    }
  }

  Future<void> _redoSetup() async {
    await UserPrefs.setSetupComplete(false);
    if (mounted) {
      context.go('/language');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text(
                    'Saved only on this phone. No account.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _languageCode,
                            decoration: const InputDecoration(labelText: 'Language'),
                            items: AppLanguage.supported
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang.code,
                                    child: Text(lang.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _languageCode = value);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Your name'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emergencyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Emergency contact name',
                              hintText: 'e.g. Harry',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emergencyController,
                            decoration: const InputDecoration(
                              labelText: 'Emergency contact phone',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Voice speed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Slider(
                            value: _voiceSpeed,
                            min: 0.2,
                            max: 0.8,
                            onChanged: (value) => setState(() => _voiceSpeed = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _redoSetup,
                    child: const Text('Change language / redo setup'),
                  ),
                ],
              ),
      ),
    );
  }
}

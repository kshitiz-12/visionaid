import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/voice_providers.dart';
import '../../../../core/services/spoken_confirm.dart';
import '../../../../core/services/user_prefs.dart';

enum _SetupStep { name, contactName, phone }

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  _SetupStep _step = _SetupStep.name;
  String _name = '';
  String _contactName = '';
  String _phone = '';
  String _status = 'Say your name.';
  bool _busy = false;
  bool _awaitingConfirm = false;
  String _pending = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askCurrent());
  }

  Future<AppLanguage> _lang() async {
    return AppLanguage.fromCode(await UserPrefs.getLanguageCode());
  }

  Future<void> _askCurrent() async {
    final lang = await _lang();
    await ref.read(textToSpeechProvider).setLocale(lang.ttsLocale);
    final prompt = switch (_step) {
      _SetupStep.name =>
        lang.code == 'hi' ? 'अपना नाम बोलें।' : 'Please say your name.',
      _SetupStep.contactName => lang.code == 'hi'
          ? 'आपातकालीन संपर्क का नाम बोलें।'
          : 'Say the name of your emergency contact. For example, Harry.',
      _SetupStep.phone => lang.code == 'hi'
          ? 'आपातकालीन फ़ोन नंबर अंकों में बोलें।'
          : 'Say the emergency phone number, digit by digit.',
    };
    if (!mounted) {
      return;
    }
    setState(() {
      _status = prompt;
      _awaitingConfirm = false;
      _pending = '';
    });
    await ref.read(textToSpeechProvider).speak(prompt);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _listen();
  }

  Future<void> _listen() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final lang = await _lang();
    final tts = ref.read(textToSpeechProvider);
    final stt = ref.read(speechToTextProvider);

    try {
      await tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      setState(() => _status = 'Listening…');
      final spoken = await stt.listen(
        localeId: lang.sttLocale,
        timeout: _step == _SetupStep.phone
            ? const Duration(seconds: 14)
            : const Duration(seconds: 8),
      );

      if (_awaitingConfirm) {
        if (SpokenConfirm.isYes(spoken)) {
          await _commitPending();
        } else {
          await _askCurrent();
        }
        return;
      }

      if (_step == _SetupStep.phone) {
        final digits = SpokenConfirm.digitsFromSpeech(spoken);
        if (digits.length < 8) {
          final msg = lang.code == 'hi'
              ? 'नंबर साफ़ नहीं सुना। फिर से बोलें।'
              : 'I did not catch a valid number. Please say the digits again.';
          setState(() => _status = msg);
          await tts.speak(msg);
          return;
        }
        _pending = digits;
      } else {
        _pending = spoken.trim();
      }

      final confirm = lang.code == 'hi'
          ? 'मैंने सुना: $_pending. सही है तो हाँ बोलें। गलत हो तो नहीं बोलें।'
          : 'I heard: $_pending. Say yes to confirm, or no to try again.';
      setState(() {
        _awaitingConfirm = true;
        _status = confirm;
      });
      await tts.speak(confirm);
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      if (mounted) {
        setState(() => _status = message);
      }
      await tts.speak(message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (mounted && _awaitingConfirm && _pending.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _listen();
    }
  }

  Future<void> _commitPending() async {
    if (_step == _SetupStep.name) {
      _name = _pending;
      _step = _SetupStep.contactName;
    } else if (_step == _SetupStep.contactName) {
      _contactName = _pending;
      _step = _SetupStep.phone;
    } else {
      _phone = _pending;
      await _finish();
      return;
    }
    _awaitingConfirm = false;
    _pending = '';
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _askCurrent();
        }
      });
    }
  }

  Future<void> _finish() async {
    await UserPrefs.setName(_name);
    await UserPrefs.setEmergencyContactName(_contactName);
    await UserPrefs.setEmergencyContact(_phone);
    await UserPrefs.setSetupComplete(true);

    final lang = await _lang();
    final done = lang.code == 'hi'
        ? 'सेटअप पूरा। VisionAid तैयार है।'
        : 'Setup complete. VisionAid is ready.';
    setState(() {
      _status = done;
      _awaitingConfirm = false;
    });
    await ref.read(textToSpeechProvider).speak(done);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepLabel = switch (_step) {
      _SetupStep.name => 'Your name',
      _SetupStep.contactName => 'Emergency contact name',
      _SetupStep.phone => 'Emergency phone',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Voice setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stepLabel,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _listen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                ),
                child: Text(_busy ? 'Listening…' : 'Tap and speak'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

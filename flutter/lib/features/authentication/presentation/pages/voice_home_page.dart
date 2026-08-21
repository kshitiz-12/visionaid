import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/voice/presentation/providers/voice_provider.dart';
import '../../../../features/voice/presentation/widgets/voice_command_button.dart';
import '../../../../features/voice/presentation/widgets/voice_status_banner.dart';

class VoiceHomePage extends ConsumerStatefulWidget {
  const VoiceHomePage({super.key});

  @override
  ConsumerState<VoiceHomePage> createState() => _VoiceHomePageState();
}

class _VoiceHomePageState extends ConsumerState<VoiceHomePage> {
  String _status = 'Ready for voice input';
  bool _isAlert = false;

  Future<void> _runVoiceDemo(String spokenText) async {
    try {
      final command = await ref.read(voiceRepositoryProvider).classifyCommand(spokenText);
      final context = await ref.read(voiceRepositoryProvider).buildContext(spokenText: spokenText);

      await ref.read(voiceCommandProvider.notifier).parse(spokenText);
      await ref.read(voiceContextProvider.notifier).buildContext(spokenText);

      setState(() {
        _status = command.intent == 'emergency'
            ? 'Emergency detected. Urgency: ${context.urgency}. Focus target: ${context.target}.'
            : 'Intent: ${command.intent}. Context: ${context.environment} ${context.location}. Target: ${context.target}. Urgency: ${context.urgency}.';
        _isAlert = command.intent == 'emergency';
      });
    } catch (error) {
      setState(() {
        _status = 'Voice processing failed. Please try again.';
        _isAlert = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline_rounded),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 72,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.mic,
                          size: 72,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Tap to speak',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Listening for commands, hazards, and navigation cues.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              VoiceStatusBanner(message: _status, isAlert: _isAlert),
              const SizedBox(height: 16),
              VoiceCommandButton(
                label: 'Start Voice Session',
                onPressed: () => _runVoiceDemo('Navigate to the exit'),
                icon: Icons.record_voice_over_rounded,
              ),
              const SizedBox(height: 12),
              VoiceCommandButton(
                label: 'Emergency',
                onPressed: () => _runVoiceDemo('Emergency'),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

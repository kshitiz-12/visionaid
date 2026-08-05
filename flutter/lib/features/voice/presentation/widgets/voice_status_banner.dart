import 'package:flutter/material.dart';

class VoiceStatusBanner extends StatelessWidget {
  const VoiceStatusBanner({
    super.key,
    required this.message,
    this.isAlert = false,
  });

  final String message;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isAlert ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAlert
              ? scheme.error.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isAlert ? scheme.onErrorContainer : scheme.onSurface,
              ),
        ),
      ),
    );
  }
}

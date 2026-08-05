import 'package:flutter/material.dart';

class VoiceCommandButton extends StatelessWidget {
  const VoiceCommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.record_voice_over_rounded),
      label: Text(label),
    );
  }
}

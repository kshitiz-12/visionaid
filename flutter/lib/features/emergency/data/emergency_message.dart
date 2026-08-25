class EmergencyMessage {
  EmergencyMessage._();

  static String body({
    required String userName,
    double? latitude,
    double? longitude,
  }) {
    final who = userName.trim().isEmpty ? 'A VisionAid user' : userName.trim();
    if (latitude == null || longitude == null) {
      return 'EMERGENCY: $who needs help. Location unavailable.';
    }
    return 'EMERGENCY: $who needs help. Last location: https://maps.google.com/?q=$latitude,$longitude';
  }
}

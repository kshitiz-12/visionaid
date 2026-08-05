class AppConfig {
  const AppConfig._();

  static const String appName = 'VisionAid++';
  static const bool isDebugMode = true;
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.visionaid.local',
  );

  static const bool enableOfflineMode = true;
  static const bool enableVoiceFirstUi = true;
}

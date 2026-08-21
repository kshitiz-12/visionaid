class AppConfig {
  const AppConfig._();

  static const String appName = 'VisionAid++';

  static const bool isDebugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String passwordResetRedirectTo = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_TO',
    defaultValue: 'io.supabase.visionaid://login-callback/',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isReleaseBuild => !isDebugMode;

  static void assertProductionConfig() {
    if (isReleaseBuild && !isSupabaseConfigured) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY are required in release builds.',
      );
    }
  }

  static const bool enableOfflineMode = true;
  static const bool enableVoiceFirstUi = true;
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'VisionAid++';

  static String get apiBaseUrl =>
      _get('API_BASE_URL', 'https://visionaid-r29c.onrender.com');

  static String get supabaseUrl => _get('SUPABASE_URL', '');

  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY', '');

  static bool get isDebugMode =>
      _get('DEBUG_MODE', 'true').toLowerCase() != 'false';

  static String get geoapifyApiKey => _get('GEOAPIFY_API_KEY', '');

  static bool get isGeoapifyConfigured =>
      geoapifyApiKey.isNotEmpty && !geoapifyApiKey.contains('YOUR_');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE');

  static const bool enableOfflineMode = true;
  static const bool enableVoiceFirstUi = true;

  static String _get(String key, String fallback) {
    if (!dotenv.isInitialized) {
      return fallback;
    }
    return dotenv.maybeGet(key) ?? fallback;
  }

  /// Call once in main(). Then just use: flutter run / flutter build apk
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      try {
        await dotenv.load(fileName: '.env.example');
      } catch (_) {
        // App still runs offline without cloud config.
      }
    }
  }
}

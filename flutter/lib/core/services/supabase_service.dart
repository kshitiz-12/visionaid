import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;

  static SupabaseClient get client {
    final instance = _client ?? Supabase.instance.client;
    return instance;
  }

  static bool get isInitialized => _client != null || AppConfig.isSupabaseConfigured;

  static Future<void> initialize() async {
    if (!AppConfig.isSupabaseConfigured) {
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _client = Supabase.instance.client;
  }
}

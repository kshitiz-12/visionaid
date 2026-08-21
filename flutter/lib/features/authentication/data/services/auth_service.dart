import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/app_config.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/app_user.dart';

class AuthService {
  AuthService({supabase.SupabaseClient? client})
      : _client = client ?? (AppConfig.isSupabaseConfigured ? SupabaseService.client : null);

  final supabase.SupabaseClient? _client;

  supabase.SupabaseClient get _supabase {
    final client = _client;
    if (client == null) {
      throw const AppException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
    return client;
  }

  Stream<supabase.AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  supabase.User? get currentUser => _client?.auth.currentUser;

  AppUser? get currentAppUser {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['display_name'] as String? ??
          '',
    );
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AppException('Sign in failed', code: 'AUTH_SIGN_IN_FAILED');
      }

      return _toAppUser(user, fallbackEmail: email);
    } on supabase.AuthException catch (error) {
      throw AppException(_mapAuthMessage(error), code: 'AUTH_SIGN_IN_FAILED');
    }
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': displayName.trim()},
      );

      final user = response.user;
      if (user == null) {
        throw const AppException('Sign up failed', code: 'AUTH_SIGN_UP_FAILED');
      }

      return AppUser(
        id: user.id,
        email: user.email ?? email,
        displayName: displayName.trim(),
      );
    } on supabase.AuthException catch (error) {
      throw AppException(_mapAuthMessage(error), code: 'AUTH_SIGN_UP_FAILED');
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'io.supabase.visionaid://login-callback/',
      );
    } on supabase.AuthException catch (error) {
      throw AppException(_mapAuthMessage(error), code: 'AUTH_RESET_FAILED');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on supabase.AuthException catch (error) {
      throw AppException(_mapAuthMessage(error), code: 'AUTH_SIGN_OUT_FAILED');
    }
  }

  AppUser _toAppUser(supabase.User user, {required String fallbackEmail}) {
    return AppUser(
      id: user.id,
      email: user.email ?? fallbackEmail,
      displayName: user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['display_name'] as String? ??
          '',
    );
  }

  String _mapAuthMessage(supabase.AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('password')) {
      return 'Password does not meet requirements.';
    }
    return error.message;
  }
}

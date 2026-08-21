import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase hide AuthState;

import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/data/services/auth_service.dart';
import '../../features/authentication/domain/entities/auth_state.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authServiceProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Single source of truth for authentication state.
final authStateProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.loading()) {
    _bootstrap();
  }

  final AuthRepository _repository;

  Future<void> _bootstrap() async {
    if (!AppConfig.isSupabaseConfigured) {
      state = const AuthState.unauthenticated();
      return;
    }

    final current = _repository.currentUser;
    if (current != null) {
      state = AuthState.authenticated(current);
    } else {
      state = const AuthState.unauthenticated();
    }

    _repository.watchAuthUser().listen((user) {
      if (user == null) {
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(user);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthState.loading();
    try {
      final user = await _repository.signIn(email: email, password: password);
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(_messageFrom(error));
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(_messageFrom(error));
      rethrow;
    }
  }

  Future<void> resetPassword({required String email}) async {
    await _repository.resetPassword(email: email);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState.unauthenticated();
  }

  String _messageFrom(Object error) {
    if (error is supabase.AuthException) {
      return error.message;
    }
    return error.toString();
  }
}

/// Listenable bridge so GoRouter can react to auth changes.
class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  AuthState get state => _ref.read(authStateProvider);
}

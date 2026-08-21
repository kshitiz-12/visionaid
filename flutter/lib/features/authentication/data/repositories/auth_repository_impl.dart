import '../../../../core/config/app_config.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authService);

  final AuthService _authService;

  @override
  Stream<AppUser?> watchAuthUser() async* {
    if (!AppConfig.isSupabaseConfigured) {
      yield null;
      return;
    }

    yield _authService.currentAppUser;

    await for (final event in _authService.authStateChanges) {
      final user = event.session?.user;
      if (user == null) {
        yield null;
        continue;
      }

      yield AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['display_name'] as String? ??
            '',
      );
    }
  }

  @override
  AppUser? get currentUser => _authService.currentAppUser;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) {
    return _authService.signIn(email: email, password: password);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  @override
  Future<void> resetPassword({required String email}) {
    return _authService.resetPassword(email: email);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }
}

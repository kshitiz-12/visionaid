import '../entities/app_user.dart';

/// Application authentication state consumed by Riverpod providers.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  /// Guest mode — full app access, no cloud account.
  const AuthState.guest()
      : status = AuthStatus.guest,
        user = null,
        errorMessage = null;

  const AuthState.authenticated(this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null;

  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null;

  const AuthState.error(String message)
      : status = AuthStatus.error,
        user = null,
        errorMessage = message;

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;
  bool get canUseApp => isAuthenticated || isGuest;
  bool get isLoading => status == AuthStatus.loading;
}

enum AuthStatus {
  guest,
  authenticated,
  loading,
  error,
}

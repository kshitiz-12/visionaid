class AuthSession {
  const AuthSession({
    required this.isAuthenticated,
    required this.userId,
    required this.email,
    required this.displayName,
  });

  const AuthSession.unauthenticated()
      : isAuthenticated = false,
        userId = null,
        email = null,
        displayName = null;

  const AuthSession.authenticated({
    required this.userId,
    required this.email,
    this.displayName,
  }) : isAuthenticated = true;

  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? displayName;

  bool get isReady => email != null && userId != null;
}

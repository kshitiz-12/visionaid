import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/domain/entities/auth_session.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authSessionProvider = StateNotifierProvider<AuthSessionController, AuthSession>(
  (ref) => AuthSessionController(),
);

class AuthSessionController extends StateNotifier<AuthSession> {
  AuthSessionController() : super(const AuthSession.unauthenticated());

  void signIn({required String userId, required String email}) {
    state = AuthSession.authenticated(
      userId: userId,
      email: email,
    );
  }

  void signOut() {
    state = const AuthSession.unauthenticated();
  }
}

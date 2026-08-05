import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

final authStateProvider = StateNotifierProvider<AuthController, AuthSession>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthSession> {
  AuthController(this._repository) : super(const AuthSession.unauthenticated());

  final AuthRepository _repository;

  Future<void> signIn({required String email, required String password}) async {
    await _repository.signIn(email: email, password: password);
    state = AuthSession.authenticated(
      userId: 'demo-user',
      email: email,
      displayName: 'VisionAid User',
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    state = AuthSession.authenticated(
      userId: 'new-user',
      email: email,
      displayName: displayName,
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthSession.unauthenticated();
  }
}

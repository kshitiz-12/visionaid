import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchAuthUser();

  AppUser? get currentUser;

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> resetPassword({required String email});

  Future<void> signOut();
}

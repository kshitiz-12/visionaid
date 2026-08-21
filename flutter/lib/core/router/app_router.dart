import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/domain/entities/auth_state.dart';
import '../../features/authentication/presentation/pages/auth_page.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/profile_page.dart';
import '../../features/authentication/presentation/pages/splash_page.dart';
import '../../features/authentication/presentation/pages/voice_home_page.dart';
import '../providers/app_providers.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthRouterNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = authNotifier.state;
      final loc = state.matchedLocation;
      final isSplash = loc == '/';
      final isAuthRoute = loc == '/auth' || loc.startsWith('/auth/');

      if (auth.status == AuthStatus.loading) {
        return isSplash ? null : '/';
      }

      if (!auth.isAuthenticated) {
        if (isAuthRoute) {
          return null;
        }
        return '/auth';
      }

      if (isSplash || isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const VoiceHomePage(),
      ),
    ],
  );
});

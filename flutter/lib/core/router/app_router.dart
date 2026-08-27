import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/pages/settings_page.dart';
import '../../features/authentication/presentation/pages/splash_page.dart';
import '../../features/authentication/presentation/pages/voice_home_page.dart';
import '../../features/navigation/presentation/pages/outdoor_route_page.dart';
import '../../features/onboarding/presentation/pages/language_page.dart';
import '../../features/onboarding/presentation/pages/setup_page.dart';
import '../../features/vision/presentation/pages/live_vision_page.dart';
import '../services/user_prefs.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final setupDone = await UserPrefs.isSetupComplete();

      if (loc == '/') {
        return setupDone ? '/home' : '/language';
      }

      if (!setupDone && loc != '/language' && loc != '/setup') {
        return '/language';
      }

      if (setupDone && (loc == '/language' || loc == '/setup')) {
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
        path: '/language',
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const VoiceHomePage(),
      ),
      GoRoute(
        path: '/live',
        builder: (context, state) => LiveVisionPage(
          findTarget: state.uri.queryParameters['target'] ?? '',
        ),
      ),
      GoRoute(
        path: '/route',
        builder: (context, state) => OutdoorRoutePage(
          destination: state.uri.queryParameters['dest'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

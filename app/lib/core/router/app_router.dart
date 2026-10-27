import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/comfort/presentation/comfort_screen.dart';
import '../../features/faults/presentation/fault_detail_screen.dart';
import '../../features/faults/presentation/faults_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/help_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/theme_settings_screen.dart';
import '../app_strings.dart';
import '../widgets/app_shell.dart';
import '../widgets/placeholder_view.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod auth state to go_router so redirects rerun on sign-in and sign-out.
  final isSignedIn = ValueNotifier<bool>(
    ref.read(authControllerProvider) != null,
  );
  ref.listen(
    authControllerProvider,
    (_, session) => isSignedIn.value = session != null,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: isSignedIn,
    redirect: (_, state) => resolveRedirect(
      isSignedIn: isSignedIn.value,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: AppRoutes.comfort,
        builder: (_, _) => const ComfortScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.themeSettings,
        builder: (_, _) => const ThemeSettingsScreen(),
      ),
      GoRoute(path: AppRoutes.help, builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: AppRoutes.faultDetail,
        builder: (_, state) =>
            FaultDetailScreen(faultId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _tab(AppRoutes.home, const HomeScreen()),
          _tab(AppRoutes.faults, const FaultsScreen()),
          // Placeholder only: the repairs feature belongs to Member C (app-dev/repairs-*).
          _tab(
            AppRoutes.repairs,
            const PlaceholderView(
              title: AppStrings.repairsTab,
              icon: Icons.build_outlined,
              message: AppStrings.repairsPlaceholder,
            ),
          ),
          _tab(AppRoutes.profile, const ProfileScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    isSignedIn.dispose();
  });
  return router;
});

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

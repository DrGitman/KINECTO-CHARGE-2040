import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/domain/app_preferences.dart';
import 'features/settings/presentation/accessibility_overrides.dart';
import 'features/settings/presentation/preferences_controller.dart';

class KinectoCareApp extends ConsumerWidget {
  const KinectoCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(preferencesControllerProvider).value ??
        AppPreferences.defaults;
    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeFor(preferences.themeChoice),
      routerConfig: ref.watch(appRouterProvider),
      builder: (_, child) => AccessibilityOverrides(
        preferences: preferences,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../domain/app_preferences.dart';

/// Applies the in-app text size and motion choices on top of the phone settings.
class AccessibilityOverrides extends StatelessWidget {
  const AccessibilityOverrides({
    super.key,
    required this.preferences,
    required this.child,
  });

  static const double largerTextFactor = 1.2;

  final AppPreferences preferences;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final phoneFactor = media.textScaler.scale(1);
    return MediaQuery(
      data: media.copyWith(
        textScaler: preferences.largerText
            ? TextScaler.linear(phoneFactor * largerTextFactor)
            : media.textScaler,
        disableAnimations: media.disableAnimations || preferences.reduceMotion,
      ),
      child: child,
    );
  }
}

ThemeMode themeModeFor(ThemeChoice choice) => switch (choice) {
  ThemeChoice.system => ThemeMode.system,
  ThemeChoice.light => ThemeMode.light,
  ThemeChoice.dark => ThemeMode.dark,
};

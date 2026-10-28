enum ThemeChoice { system, light, dark }

/// Alert types the wearer may turn off. Fault alerts are not listed: they are always on.
enum OptionalAlert {
  repairUpdates,
  energyTips,
  comfortChanges,
  feedbackRequests,
}

/// Display and notification choices kept on this phone.
class AppPreferences {
  const AppPreferences({
    required this.themeChoice,
    required this.largerText,
    required this.reduceMotion,
    required this.enabledAlerts,
  });

  // Alert defaults follow board 04b, screen 32.
  static const AppPreferences defaults = AppPreferences(
    themeChoice: ThemeChoice.system,
    largerText: false,
    reduceMotion: false,
    enabledAlerts: {
      OptionalAlert.repairUpdates,
      OptionalAlert.feedbackRequests,
    },
  );

  final ThemeChoice themeChoice;
  final bool largerText;
  final bool reduceMotion;
  final Set<OptionalAlert> enabledAlerts;

  bool isAlertEnabled(OptionalAlert alert) => enabledAlerts.contains(alert);

  AppPreferences copyWith({
    ThemeChoice? themeChoice,
    bool? largerText,
    bool? reduceMotion,
    Set<OptionalAlert>? enabledAlerts,
  }) => AppPreferences(
    themeChoice: themeChoice ?? this.themeChoice,
    largerText: largerText ?? this.largerText,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    enabledAlerts: enabledAlerts ?? this.enabledAlerts,
  );

  AppPreferences withAlert(OptionalAlert alert, {required bool enabled}) =>
      copyWith(
        enabledAlerts: enabled
            ? {...enabledAlerts, alert}
            : enabledAlerts.difference({alert}),
      );
}

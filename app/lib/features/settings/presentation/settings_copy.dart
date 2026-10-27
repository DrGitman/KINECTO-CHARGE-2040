import '../../../core/app_strings.dart';
import '../domain/app_preferences.dart';

abstract final class SettingsCopy {
  static String themeLabel(ThemeChoice choice) => switch (choice) {
    ThemeChoice.system => AppStrings.matchMyPhone,
    ThemeChoice.light => AppStrings.themeLight,
    ThemeChoice.dark => AppStrings.themeDark,
  };

  static String alertTitle(OptionalAlert alert) => switch (alert) {
    OptionalAlert.repairUpdates => AppStrings.repairUpdates,
    OptionalAlert.energyTips => AppStrings.energyTips,
    OptionalAlert.comfortChanges => AppStrings.comfortChanges,
    OptionalAlert.feedbackRequests => AppStrings.feedbackRequests,
  };

  static String alertHint(OptionalAlert alert) => switch (alert) {
    OptionalAlert.repairUpdates => AppStrings.repairUpdatesHint,
    OptionalAlert.energyTips => AppStrings.energyTipsHint,
    OptionalAlert.comfortChanges => AppStrings.comfortChangesHint,
    OptionalAlert.feedbackRequests => AppStrings.feedbackRequestsHint,
  };
}

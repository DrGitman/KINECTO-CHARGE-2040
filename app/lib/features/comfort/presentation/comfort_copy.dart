import '../../../core/app_strings.dart';
import '../domain/comfort_settings.dart';

abstract final class ComfortCopy {
  static String modeLabel(ComfortMode mode) => switch (mode) {
    ComfortMode.auto => AppStrings.modeAuto,
    ComfortMode.cool => AppStrings.modeCool,
    ComfortMode.warm => AppStrings.modeWarm,
    ComfortMode.off => AppStrings.modeOff,
  };

  static String degrees(int celsius) => '$celsius°C';

  static String prewarmTime(PrewarmTime time) =>
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

import 'comfort_settings.dart';

class InvalidComfortSettingsException implements Exception {
  const InvalidComfortSettingsException(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidComfortSettingsException: $reason';
}

/// Bounds for the Auto mode thresholds, same scale as the comfort gauge.
abstract final class ComfortLimits {
  static const int minC = 18;
  static const int maxC = 28;
  static const int stepC = 1;

  // The firmware hysteresis is 0.7 °C on each side, so 2 °C keeps heat and cool bands apart.
  static const int minGapC = 2;

  static bool canStepWarm(ComfortSettings settings, int delta) =>
      _isValid(settings.warmBelowC + delta * stepC, settings.coolAboveC);

  static bool canStepCool(ComfortSettings settings, int delta) =>
      _isValid(settings.warmBelowC, settings.coolAboveC + delta * stepC);

  static void validate(ComfortSettings settings) {
    if (!_isValid(settings.warmBelowC, settings.coolAboveC)) {
      throw InvalidComfortSettingsException(
        'warm ${settings.warmBelowC} °C and cool ${settings.coolAboveC} °C '
        'must sit in $minC..$maxC °C at least $minGapC °C apart',
      );
    }
  }

  static bool _isValid(int warmBelowC, int coolAboveC) =>
      warmBelowC >= minC &&
      coolAboveC <= maxC &&
      coolAboveC - warmBelowC >= minGapC;
}

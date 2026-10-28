import 'comfort_settings.dart';

abstract interface class ComfortRepository {
  Future<ComfortSettings> fetchSettings();

  /// Stores the settings and returns them with the save time.
  Future<ComfortSettings> saveSettings(ComfortSettings settings);

  /// Settings changed elsewhere: the jacket's mode button or another device.
  Stream<ComfortSettings> watchSettings();
}

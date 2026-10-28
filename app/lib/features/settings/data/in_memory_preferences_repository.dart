import '../domain/app_preferences.dart';
import '../domain/preferences_repository.dart';

/// Keeps preferences for the running session only, until local storage is added.
class InMemoryPreferencesRepository implements PreferencesRepository {
  AppPreferences _preferences = AppPreferences.defaults;

  @override
  Future<AppPreferences> fetch() async => _preferences;

  @override
  Future<AppPreferences> save(AppPreferences preferences) async =>
      _preferences = preferences;
}

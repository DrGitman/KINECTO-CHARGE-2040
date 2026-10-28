import 'app_preferences.dart';

abstract interface class PreferencesRepository {
  Future<AppPreferences> fetch();

  Future<AppPreferences> save(AppPreferences preferences);
}

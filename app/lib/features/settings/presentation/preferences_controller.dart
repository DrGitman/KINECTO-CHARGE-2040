import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_preferences_repository.dart';
import '../domain/app_preferences.dart';
import '../domain/preferences_repository.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => InMemoryPreferencesRepository(),
);

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
    );

class PreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() =>
      ref.read(preferencesRepositoryProvider).fetch();

  Future<void> setThemeChoice(ThemeChoice choice) =>
      _update((current) => current.copyWith(themeChoice: choice));

  Future<void> setLargerText(bool enabled) =>
      _update((current) => current.copyWith(largerText: enabled));

  Future<void> setReduceMotion(bool enabled) =>
      _update((current) => current.copyWith(reduceMotion: enabled));

  Future<void> setAlertEnabled(OptionalAlert alert, bool enabled) =>
      _update((current) => current.withAlert(alert, enabled: enabled));

  // Shows the change at once and rolls back if the save fails.
  Future<void> _update(
    AppPreferences Function(AppPreferences current) change,
  ) async {
    final current = state.value;
    if (current == null) return;
    final next = change(current);
    state = AsyncData(next);
    try {
      state = AsyncData(
        await ref.read(preferencesRepositoryProvider).save(next),
      );
    } on Exception catch (error) {
      debugPrint('[preferences] save failed, keeping previous values: $error');
      state = AsyncData(current);
    }
  }
}

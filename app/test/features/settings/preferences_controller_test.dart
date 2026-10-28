import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/settings/domain/app_preferences.dart';
import 'package:kinecto_care/features/settings/domain/preferences_repository.dart';
import 'package:kinecto_care/features/settings/presentation/preferences_controller.dart';

class _FailingPreferencesRepository implements PreferencesRepository {
  @override
  Future<AppPreferences> fetch() async => AppPreferences.defaults;

  @override
  Future<AppPreferences> save(AppPreferences preferences) =>
      Future.error(Exception('storage unavailable'));
}

void main() {
  late ProviderContainer container;

  tearDown(() => container.dispose());

  PreferencesController controller() =>
      container.read(preferencesControllerProvider.notifier);
  AppPreferences current() =>
      container.read(preferencesControllerProvider).requireValue;

  group('with the in-memory repository', () {
    setUp(() => container = ProviderContainer());

    test('starts by following the phone, alerts as on board 32', () async {
      final loaded = await container.read(preferencesControllerProvider.future);

      expect(loaded.themeChoice, ThemeChoice.system);
      expect(loaded.largerText, isFalse);
      expect(loaded.reduceMotion, isFalse);
      expect(loaded.isAlertEnabled(OptionalAlert.repairUpdates), isTrue);
      expect(loaded.isAlertEnabled(OptionalAlert.energyTips), isFalse);
      expect(loaded.isAlertEnabled(OptionalAlert.comfortChanges), isFalse);
      expect(loaded.isAlertEnabled(OptionalAlert.feedbackRequests), isTrue);
    });

    test('saves theme, text and motion choices', () async {
      await container.read(preferencesControllerProvider.future);

      await controller().setThemeChoice(ThemeChoice.dark);
      await controller().setLargerText(true);
      await controller().setReduceMotion(true);

      expect(current().themeChoice, ThemeChoice.dark);
      expect(current().largerText, isTrue);
      expect(current().reduceMotion, isTrue);
    });

    test('toggles one alert without touching the others', () async {
      await container.read(preferencesControllerProvider.future);

      await controller().setAlertEnabled(OptionalAlert.energyTips, true);
      await controller().setAlertEnabled(OptionalAlert.repairUpdates, false);

      expect(current().isAlertEnabled(OptionalAlert.energyTips), isTrue);
      expect(current().isAlertEnabled(OptionalAlert.repairUpdates), isFalse);
      expect(current().isAlertEnabled(OptionalAlert.feedbackRequests), isTrue);
    });
  });

  test('rolls back when the save fails', () async {
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          _FailingPreferencesRepository(),
        ),
      ],
    );
    await container.read(preferencesControllerProvider.future);

    await controller().setThemeChoice(ThemeChoice.dark);

    expect(current().themeChoice, ThemeChoice.system);
  });
}

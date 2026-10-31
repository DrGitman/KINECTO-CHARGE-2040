import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/comfort/domain/comfort_settings.dart';
import 'package:kinecto_care/features/comfort/presentation/comfort_controller.dart';
import 'package:kinecto_care/features/faults/presentation/faults_controller.dart';

import '../../helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer(overrides: [fixedClockOverride]));
  tearDown(() => container.dispose());

  ComfortController controller() =>
      container.read(comfortControllerProvider.notifier);
  ComfortEditor editor() =>
      container.read(comfortControllerProvider).requireValue;

  test('starts from the thermal contract defaults, heating off', () async {
    final loaded = await container.read(comfortControllerProvider.future);

    expect(loaded.saved.mode, ComfortMode.auto);
    expect(loaded.saved.warmBelowC, 19);
    expect(loaded.saved.coolAboveC, 26);
    expect(loaded.saved.prewarmEnabled, isFalse);
    expect(loaded.hasChanges, isFalse);
  });

  test('edits stay in the draft until saved', () async {
    await container.read(comfortControllerProvider.future);

    controller()
      ..selectMode(ComfortMode.cool)
      ..stepWarmBelow(1)
      ..setPrewarmEnabled(true);

    expect(editor().hasChanges, isTrue);
    expect(editor().saved.mode, ComfortMode.auto);

    await controller().save();

    expect(editor().hasChanges, isFalse);
    expect(editor().saved.mode, ComfortMode.cool);
    expect(editor().saved.warmBelowC, 20);
    expect(editor().saved.updatedAt, testNow);
  });

  test('warm threshold stops at the gap below cool', () async {
    await container.read(comfortControllerProvider.future);

    for (var i = 0; i < 10; i++) {
      controller().stepWarmBelow(1);
    }

    expect(editor().draft.warmBelowC, 24);
  });

  test('inside reading is hidden while the sensor fault is open', () async {
    container.listen(insideReadingProvider, (_, _) {});
    expect(await container.read(insideReadingProvider.future), isNull);

    final open = (await container.read(
      faultsControllerProvider.future,
    )).firstWhere((fault) => fault.isOpen);
    await container
        .read(faultsControllerProvider.notifier)
        .markResolved(open.id);

    expect(await container.read(insideReadingProvider.future), 24.0);
  });
}

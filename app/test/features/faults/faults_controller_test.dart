import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/faults/domain/fault.dart';
import 'package:kinecto_care/features/faults/domain/fault_repository.dart';
import 'package:kinecto_care/features/faults/presentation/faults_controller.dart';

import '../../helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer(overrides: [fixedClockOverride]));
  tearDown(() => container.dispose());

  test('loads the log newest first', () async {
    final faults = await container.read(faultsControllerProvider.future);

    final times = faults.map((fault) => fault.detectedAt).toList();
    expect(times, [...times]..sort((a, b) => b.compareTo(a)));
  });

  test('marking the open fault resolved leaves no open fault', () async {
    await container.read(faultsControllerProvider.future);
    final open = container.read(openFaultsProvider);
    expect(open, hasLength(1));

    await container
        .read(faultsControllerProvider.notifier)
        .markResolved(open.single.id);

    expect(container.read(openFaultsProvider), isEmpty);
    final faults = container.read(faultsControllerProvider).requireValue;
    expect(
      faults.firstWhere((fault) => fault.id == open.single.id).status,
      FaultStatus.fixed,
    );
  });

  test('resolving an unknown fault throws', () async {
    await container.read(faultsControllerProvider.future);

    expect(
      container.read(faultsControllerProvider.notifier).markResolved('F-NONE'),
      throwsA(isA<FaultNotFoundException>()),
    );
  });
}

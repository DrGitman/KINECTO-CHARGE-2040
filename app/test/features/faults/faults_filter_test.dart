import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/faults/domain/fault.dart';
import 'package:kinecto_care/features/faults/presentation/faults_filter.dart';

import '../../helpers.dart';

Fault _fault(FaultCode code, DateTime detectedAt) => Fault(
  id: 'F-TEST',
  jacketId: 'KC-SIM-0001',
  code: code,
  status: FaultStatus.open,
  source: FaultSource.jacket,
  detectedAt: detectedAt,
);

void main() {
  test('accepts only the selected month and subsystem', () {
    final filter = FaultsFilter(
      month: DateTime(2026, 10),
      subsystem: FaultSubsystem.thermal,
    );

    expect(
      filter.accepts(_fault(FaultCode.heaterOverLimit, DateTime(2026, 10, 3))),
      isTrue,
    );
    expect(
      filter.accepts(_fault(FaultCode.heaterOverLimit, DateTime(2026, 9, 30))),
      isFalse,
    );
    expect(
      filter.accepts(
        _fault(FaultCode.cuffTagUnreadable, DateTime(2026, 10, 3)),
      ),
      isFalse,
    );
  });

  test('starts on the current month and shifts across years', () {
    final container = ProviderContainer(overrides: [fixedClockOverride]);
    addTearDown(container.dispose);

    expect(container.read(faultsFilterProvider).month, DateTime(2026, 10));

    container.read(faultsFilterProvider.notifier).shiftMonth(3);
    expect(container.read(faultsFilterProvider).month, DateTime(2027, 1));
  });

  test('maps every fault ID back to its code', () {
    for (final code in FaultCode.values) {
      expect(FaultCode.fromId(code.id), code);
    }
    expect(FaultCode.fromId('unknown_flag'), isNull);
  });
}

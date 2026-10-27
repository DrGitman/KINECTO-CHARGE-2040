import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../domain/fault.dart';

class FaultsFilter {
  const FaultsFilter({required this.month, this.subsystem});

  /// First day of the month shown in the log.
  final DateTime month;

  /// Null shows every subsystem.
  final FaultSubsystem? subsystem;

  bool accepts(Fault fault) =>
      fault.detectedAt.year == month.year &&
      fault.detectedAt.month == month.month &&
      (subsystem == null || fault.subsystem == subsystem);
}

final faultsFilterProvider =
    NotifierProvider<FaultsFilterController, FaultsFilter>(
      FaultsFilterController.new,
    );

class FaultsFilterController extends Notifier<FaultsFilter> {
  @override
  FaultsFilter build() {
    final now = ref.watch(clockProvider)();
    return FaultsFilter(month: DateTime(now.year, now.month));
  }

  void showSubsystem(FaultSubsystem? subsystem) =>
      state = FaultsFilter(month: state.month, subsystem: subsystem);

  void shiftMonth(int months) => state = FaultsFilter(
    month: DateTime(state.month.year, state.month.month + months),
    subsystem: state.subsystem,
  );
}

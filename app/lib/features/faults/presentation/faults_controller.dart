import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../data/mock_fault_repository.dart';
import '../domain/fault.dart';
import '../domain/fault_repository.dart';

final faultRepositoryProvider = Provider<FaultRepository>(
  (ref) => MockFaultRepository(ref.watch(clockProvider)),
);

final faultsControllerProvider =
    AsyncNotifierProvider<FaultsController, List<Fault>>(FaultsController.new);

final openFaultsProvider = Provider<List<Fault>>((ref) {
  final faults = ref.watch(faultsControllerProvider).value ?? const [];
  return faults.where((fault) => fault.isOpen).toList();
});

/// Fault log, newest first.
class FaultsController extends AsyncNotifier<List<Fault>> {
  @override
  Future<List<Fault>> build() => _load();

  Future<void> markResolved(String faultId) async {
    try {
      await ref.read(faultRepositoryProvider).markResolved(faultId);
    } on FaultNotFoundException catch (error) {
      debugPrint('[faults] resolve failed: $error');
      rethrow;
    }
    state = AsyncData(await _load());
  }

  Future<List<Fault>> _load() async {
    final faults = await ref.read(faultRepositoryProvider).fetchFaults();
    return [...faults]..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  }
}

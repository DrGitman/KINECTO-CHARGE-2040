import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend.dart';
import '../../../core/clock.dart';
import '../data/mock_fault_repository.dart';
import '../data/supabase_fault_repository.dart';
import '../domain/fault.dart';
import '../domain/fault_repository.dart';

final faultRepositoryProvider = Provider<FaultRepository>(
  (ref) => Backend.isConfigured
      ? SupabaseFaultRepository(
          ref.watch(supabaseClientProvider),
          Backend.jacketId,
        )
      : MockFaultRepository(ref.watch(clockProvider)),
);

final faultsControllerProvider =
    AsyncNotifierProvider<FaultsController, List<Fault>>(FaultsController.new);

final openFaultsProvider = Provider<List<Fault>>((ref) {
  final faults = ref.watch(faultsControllerProvider).value ?? const [];
  return faults.where((fault) => fault.isOpen).toList();
});

/// Fault log, newest first. Live: a fault raised by the jacket shows up at once.
class FaultsController extends AsyncNotifier<List<Fault>> {
  @override
  Future<List<Fault>> build() {
    final repository = ref.read(faultRepositoryProvider);
    final subscription = repository.watchFaults().listen(
      (faults) => state = AsyncData(_newestFirst(faults)),
    );
    ref.onDispose(subscription.cancel);
    return _load();
  }

  Future<void> markResolved(String faultId) async {
    try {
      await ref.read(faultRepositoryProvider).markResolved(faultId);
    } on FaultNotFoundException catch (error) {
      debugPrint('[faults] resolve failed: $error');
      rethrow;
    }
    state = AsyncData(await _load());
  }

  Future<List<Fault>> _load() async =>
      _newestFirst(await ref.read(faultRepositoryProvider).fetchFaults());

  static List<Fault> _newestFirst(List<Fault> faults) =>
      [...faults]..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
}

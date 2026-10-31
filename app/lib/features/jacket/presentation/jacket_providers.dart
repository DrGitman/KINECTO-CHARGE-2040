import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend.dart';
import '../../../core/clock.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/jacket_history_repository.dart';
import '../data/mock_jacket_repository.dart';
import '../data/supabase_jacket_repository.dart';
import '../domain/jacket_history.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

/// The signed-in wearer's jacket (students.jacket_id), never a fixed id.
final jacketIdProvider = Provider<String>(
  (ref) => ref.watch(authControllerProvider)?.jacketId ?? Backend.jacketId,
);

final jacketRepositoryProvider = Provider<JacketRepository>(
  (ref) => Backend.connected
      ? SupabaseJacketRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(jacketIdProvider),
        )
      : MockJacketRepository(ref.watch(clockProvider)),
);

final jacketStatusProvider = StreamProvider<JacketStatus>(
  (ref) => ref.watch(jacketRepositoryProvider).watchStatus(),
);

/// No report for 2 minutes: the jacket is out of range (or the Unity lab is stopped).
const Duration jacketOfflineAfter = Duration(minutes: 2);

final jacketOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(jacketStatusProvider).value;
  if (status == null) return false;
  return ref.watch(currentTimeProvider).difference(status.updatedAt) < jacketOfflineAfter;
});

final jacketHistoryRepositoryProvider = Provider<JacketHistoryRepository>(
  (ref) => Backend.connected
      ? SupabaseJacketHistoryRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(jacketIdProvider),
        )
      : MockJacketHistoryRepository(ref.watch(clockProvider)),
);

/// Hourly totals since midnight, or daily totals for the last 7 / 30 days.
/// Refreshed every time the clock ticks (15 s) so the charts follow the lab.
final jacketHistoryProvider = FutureProvider.autoDispose
    .family<List<JacketBucket>, HistoryRange>((ref, range) {
      final now = ref.watch(currentTimeProvider);
      final today = DateTime(now.year, now.month, now.day);
      final from = switch (range) {
        HistoryRange.day => today,
        HistoryRange.week => today.subtract(const Duration(days: 6)),
        HistoryRange.month => today.subtract(const Duration(days: 29)),
      };
      return ref
          .watch(jacketHistoryRepositoryProvider)
          .buckets(from, daily: range != HistoryRange.day);
    });

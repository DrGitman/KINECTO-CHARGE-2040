import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';

typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// The time, again every 15 s while the app is live, so "2 min ago" labels and the
/// "jacket not in range" check stay current. Tests never tick (no pending timers).
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  if (!Backend.connected) return;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    yield clock();
  }
});

/// Current time from [nowProvider], falling back to the clock before the first tick.
final currentTimeProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider).value ?? ref.watch(clockProvider)(),
);

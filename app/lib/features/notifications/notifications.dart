import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backend.dart';
import '../../core/clock.dart';
import '../faults/domain/fault.dart';
import '../jacket/presentation/jacket_providers.dart';

enum JacketEventKind { faultOpened, faultFixed, comfortSynced, tap }

/// One row of jacket_events: written by database triggers when a fault opens or is fixed,
/// comfort settings change (on the jacket or in the app) or the wearer taps at a door.
class JacketEvent {
  const JacketEvent({
    required this.id,
    required this.at,
    required this.kind,
    this.code,
    this.detail,
  });

  final int id;
  final DateTime at;
  final JacketEventKind kind;
  final String? code;
  final String? detail;

  FaultCode? get faultCode => code == null ? null : FaultCode.fromId(code!);
}

final jacketEventsProvider = StreamProvider<List<JacketEvent>>((ref) {
  // Offline (tests, no Supabase) there is no event feed.
  if (!Backend.connected) return Stream.value(const <JacketEvent>[]);
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('jacket_events')
      .stream(primaryKey: ['id'])
      .eq('jacket_id', ref.watch(jacketIdProvider))
      .order('ts', ascending: false)
      .limit(60)
      .map((rows) => [for (final row in rows) _fromRow(row)]);
});

JacketEvent _fromRow(Map<String, dynamic> row) => JacketEvent(
  id: (row['id'] as num).toInt(),
  at: DateTime.parse(row['ts'] as String).toLocal(),
  kind: switch (row['kind'] as String) {
    'fault_opened' => JacketEventKind.faultOpened,
    'fault_fixed' => JacketEventKind.faultFixed,
    'comfort_synced' => JacketEventKind.comfortSynced,
    _ => JacketEventKind.tap,
  },
  code: row['code'] as String?,
  detail: row['detail'] as String?,
);

/// When the wearer last opened Notifications; newer events get the red dot (bell on Home too).
final notificationsSeenProvider =
    NotifierProvider<NotificationsSeen, DateTime?>(NotificationsSeen.new);

class NotificationsSeen extends Notifier<DateTime?> {
  static const String _key = 'kinecto.notificationsSeen';

  @override
  DateTime? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && state == null) state = DateTime.tryParse(saved);
    } catch (_) {
      // Not available in tests.
    }
  }

  Future<void> markAllSeen() async {
    final now = ref.read(clockProvider)();
    state = now;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, now.toIso8601String());
    } catch (_) {
      // Not available in tests.
    }
  }
}

final unreadNotificationsProvider = Provider<int>((ref) {
  final events = ref.watch(jacketEventsProvider).value ?? const <JacketEvent>[];
  final seen = ref.watch(notificationsSeenProvider);
  return events.where((e) => seen == null || e.at.isAfter(seen)).length;
});

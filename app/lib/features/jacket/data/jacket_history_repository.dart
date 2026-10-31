import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/clock.dart';
import '../domain/jacket_history.dart';

abstract interface class JacketHistoryRepository {
  Future<List<JacketBucket>> buckets(DateTime from, {required bool daily});
}

/// jacket_buckets() adds up the 10-second samples the database keeps while the jacket reports.
class SupabaseJacketHistoryRepository implements JacketHistoryRepository {
  SupabaseJacketHistoryRepository(this._client, this._jacketId);

  final SupabaseClient _client;
  final String _jacketId;

  @override
  Future<List<JacketBucket>> buckets(DateTime from, {required bool daily}) async {
    final rows = await _client.rpc(
      'jacket_buckets',
      params: {
        'p_jacket': _jacketId,
        'p_from': from.toUtc().toIso8601String(),
        'p_bucket': daily ? 'day' : 'hour',
      },
    ) as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        JacketBucket(
          start: DateTime.parse(row['bucket'] as String).toLocal(),
          harvestMj: _num(row['harvest_mj']) ?? 0,
          walkMinutes: _num(row['walk_min']) ?? 0,
          heaterMinutes: _num(row['heater_min']) ?? 0,
          blowerMinutes: _num(row['blower_min']) ?? 0,
          insideC: _num(row['inside_c']),
          outsideC: _num(row['outside_c']),
          batteryPercent: _num(row['battery_pct']),
        ),
    ];
  }

  static double? _num(Object? value) => (value as num?)?.toDouble();
}

/// SIMULATED history for offline runs and tests.
class MockJacketHistoryRepository implements JacketHistoryRepository {
  MockJacketHistoryRepository(this._clock);

  final Clock _clock;

  @override
  Future<List<JacketBucket>> buckets(DateTime from, {required bool daily}) async {
    final now = _clock();
    final step = daily ? const Duration(days: 1) : const Duration(hours: 1);
    final out = <JacketBucket>[];
    for (var t = from; t.isBefore(now); t = t.add(step)) {
      final i = out.length;
      if (!daily && t.hour < 7) continue;
      out.add(
        JacketBucket(
          start: t,
          harvestMj: 0.05 + (i % 5) * 0.03,
          walkMinutes: daily ? 110 : 10 + (i % 4) * 5,
          heaterMinutes: daily ? 20 : (i % 3) * 2,
          blowerMinutes: daily ? 40 : (i % 2) * 6,
          insideC: 22 + (i % 4) * 0.6,
          outsideC: 16 + i * 0.8,
          batteryPercent: 96 - i * 2.5,
        ),
      );
    }
    return out;
  }
}

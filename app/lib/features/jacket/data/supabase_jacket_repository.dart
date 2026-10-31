import 'package:supabase_flutter/supabase_flutter.dart';

import '../../comfort/domain/comfort_settings.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

/// Live jacket_status row, written by the jacket-ingest Edge Function about once a second.
class SupabaseJacketRepository implements JacketRepository {
  SupabaseJacketRepository(this._client, this._jacketId);

  final SupabaseClient _client;
  final String _jacketId;

  @override
  Stream<JacketStatus> watchStatus() => _client
      .from('jacket_status')
      .stream(primaryKey: ['jacket_id'])
      .eq('jacket_id', _jacketId)
      .map((rows) {
        if (rows.isEmpty) throw StateError('No status yet for $_jacketId');
        return _fromRow(rows.single);
      });

  static JacketStatus _fromRow(Map<String, dynamic> row) => JacketStatus(
    jacketId: row['jacket_id'] as String,
    updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    comfortBatteryPercent: _percent(row['battery_pct']),
    energyBufferPercent: _percent(row['buffer_pct']),
    insideC: (row['body_c'] as num?)?.toDouble() ?? double.nan,
    cuffTagReadable: row['cuff_tag_ok'] as bool? ?? true,
    isSimulated: row['is_virtual'] as bool? ?? false,
    outsideC: (row['ambient_c'] as num?)?.toDouble(),
    heaterOn: row['heater_on'] as bool? ?? false,
    blowerOn: row['blower_on'] as bool? ?? false,
    harvestedMj: (row['harvested_mj'] as num?)?.toDouble(),
    activity: row['activity'] as String?,
    bufferVolts: (row['buffer_v'] as num?)?.toDouble(),
    batteryTempC: (row['battery_temp_c'] as num?)?.toDouble(),
    mode: _mode(row['mode'] as String?),
    faultFlags: [for (final f in (row['fault_flags'] as List?) ?? const []) f.toString()],
  );

  static ComfortMode? _mode(String? value) {
    for (final mode in ComfortMode.values) {
      if (mode.name == value?.toLowerCase()) return mode;
    }
    return null;
  }

  static int _percent(Object? value) =>
      ((value as num?) ?? 0).round().clamp(0, 100);
}

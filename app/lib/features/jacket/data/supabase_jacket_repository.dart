import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

/// Live jacket_status row, written by the jacket-ingest Edge Function.
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
    cuffTagReadable: row['cuff_tag_ok'] as bool,
    isSimulated: row['is_virtual'] as bool,
  );

  static int _percent(Object? value) =>
      ((value as num?) ?? 0).round().clamp(0, 100);
}

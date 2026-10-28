import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend.dart';
import '../domain/comfort_limits.dart';
import '../domain/comfort_repository.dart';
import '../domain/comfort_settings.dart';

/// comfort_settings row. The jacket gets it in the jacket-ingest reply.
class SupabaseComfortRepository implements ComfortRepository {
  SupabaseComfortRepository(this._client, this._jacketId);

  final SupabaseClient _client;
  final String _jacketId;

  @override
  Future<ComfortSettings> fetchSettings() async => _fromRow(
    await _client
        .from('comfort_settings')
        .select()
        .eq('jacket_id', _jacketId)
        .single(),
  );

  @override
  Future<ComfortSettings> saveSettings(ComfortSettings settings) async {
    ComfortLimits.validate(settings);
    final at = settings.prewarmAt;
    final row = await _client
        .from('comfort_settings')
        .update({
          'mode': settings.mode.name,
          'warm_below_c': settings.warmBelowC,
          'cool_above_c': settings.coolAboveC,
          'prewarm_enabled': settings.prewarmEnabled,
          'prewarm_at': '${_two(at.hour)}:${_two(at.minute)}',
          'updated_by': 'app',
        })
        .eq('jacket_id', _jacketId)
        .select()
        .single();
    return _fromRow(row);
  }

  @override
  Stream<ComfortSettings> watchSettings() => _client
      .from('comfort_settings')
      .stream(primaryKey: ['jacket_id'])
      .eq('jacket_id', _jacketId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => _fromRow(rows.single));

  static ComfortSettings _fromRow(Map<String, dynamic> row) {
    final time = (row['prewarm_at'] as String).split(':');
    return ComfortSettings(
      jacketId: row['jacket_id'] as String,
      mode: ComfortMode.values.byName(row['mode'] as String),
      warmBelowC: row['warm_below_c'] as int,
      coolAboveC: row['cool_above_c'] as int,
      prewarmEnabled: row['prewarm_enabled'] as bool,
      prewarmAt: PrewarmTime(int.parse(time[0]), int.parse(time[1])),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      isSimulated: Backend.isVirtualJacket,
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

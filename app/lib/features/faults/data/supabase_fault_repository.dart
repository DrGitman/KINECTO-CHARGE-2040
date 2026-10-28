import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/fault.dart';
import '../domain/fault_repository.dart';

/// faults table. jacket-ingest opens a fault when the jacket raises a flag
/// and marks it fixed when the flag clears; the wearer can also mark it fixed.
class SupabaseFaultRepository implements FaultRepository {
  SupabaseFaultRepository(this._client, this._jacketId);

  final SupabaseClient _client;
  final String _jacketId;

  @override
  Future<List<Fault>> fetchFaults() async => _fromRows(
    await _client.from('faults').select().eq('jacket_id', _jacketId),
  );

  @override
  Future<void> markResolved(String faultId) async {
    final rows = await _client
        .from('faults')
        .update({
          'status': 'fixed',
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', faultId)
        .select('id');
    if (rows.isEmpty) throw FaultNotFoundException(faultId);
  }

  @override
  Stream<List<Fault>> watchFaults() => _client
      .from('faults')
      .stream(primaryKey: ['id'])
      .eq('jacket_id', _jacketId)
      .map(_fromRows);

  // Codes the app does not know yet are left out instead of failing the list.
  static List<Fault> _fromRows(List<Map<String, dynamic>> rows) => [
    for (final row in rows)
      if (FaultCode.fromId(row['code'] as String) case final code?)
        Fault(
          id: row['id'] as String,
          jacketId: row['jacket_id'] as String,
          code: code,
          status: FaultStatus.values.byName(row['status'] as String),
          source: row['source'] == 'kinecto_check'
              ? FaultSource.kinectoCheck
              : FaultSource.jacket,
          detectedAt: DateTime.parse(row['detected_at'] as String).toLocal(),
        ),
  ];
}

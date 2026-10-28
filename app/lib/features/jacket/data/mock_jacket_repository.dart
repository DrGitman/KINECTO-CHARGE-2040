import '../../../core/clock.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

/// SIMULATED snapshot of the Virtual Lab jacket until Supabase is wired.
class MockJacketRepository implements JacketRepository {
  MockJacketRepository(this._clock);

  static const String jacketId = 'KC-SIM-0001';
  static const Duration _lastSyncAgo = Duration(minutes: 2);

  final Clock _clock;

  @override
  Future<JacketStatus> fetchStatus() async => JacketStatus(
    jacketId: jacketId,
    updatedAt: _clock().subtract(_lastSyncAgo),
    comfortBatteryPercent: 92,
    energyBufferPercent: 64,
    insideC: 24.0,
    cuffTagReadable: true,
    isSimulated: true,
  );
}

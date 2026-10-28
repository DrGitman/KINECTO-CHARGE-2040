import '../../../core/clock.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

/// SIMULATED snapshot of the Virtual Lab jacket, used when Supabase is not configured.
class MockJacketRepository implements JacketRepository {
  MockJacketRepository(this._clock);

  static const String jacketId = 'KC-SIM-0001';
  static const Duration _lastSyncAgo = Duration(minutes: 2);

  final Clock _clock;

  @override
  Stream<JacketStatus> watchStatus() => Stream.value(JacketStatus(
    jacketId: jacketId,
    updatedAt: _clock().subtract(_lastSyncAgo),
    comfortBatteryPercent: 92,
    energyBufferPercent: 64,
    insideC: 24.0,
    cuffTagReadable: true,
    isSimulated: true,
    outsideC: 22.0,
    harvestedMj: 1.2,
    activity: 'walk',
  ));
}

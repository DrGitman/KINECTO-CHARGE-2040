import '../../../core/clock.dart';
import '../../jacket/data/mock_jacket_repository.dart';
import '../domain/fault.dart';
import '../domain/fault_repository.dart';

/// SIMULATED fault log of the Virtual Lab jacket, used when Supabase is not configured.
class MockFaultRepository implements FaultRepository {
  MockFaultRepository(Clock clock) : _faults = _seed(clock());

  final List<Fault> _faults;

  @override
  Future<List<Fault>> fetchFaults() async => List.unmodifiable(_faults);

  @override
  Stream<List<Fault>> watchFaults() => const Stream.empty();

  @override
  Future<void> markResolved(String faultId) async {
    final index = _faults.indexWhere((fault) => fault.id == faultId);
    if (index < 0) throw FaultNotFoundException(faultId);
    _faults[index] = _faults[index].copyWith(status: FaultStatus.fixed);
  }

  static List<Fault> _seed(DateTime now) {
    Fault fault(
      String id,
      FaultCode code,
      FaultStatus status,
      FaultSource source,
      Duration ago,
    ) => Fault(
      id: id,
      jacketId: MockJacketRepository.jacketId,
      code: code,
      status: status,
      source: source,
      detectedAt: now.subtract(ago),
    );

    return [
      fault(
        'F-SIM-0005',
        FaultCode.insideSensorSilent,
        FaultStatus.open,
        FaultSource.kinectoCheck,
        const Duration(minutes: 25),
      ),
      fault(
        'F-SIM-0004',
        FaultCode.bufferNotCharging,
        FaultStatus.watch,
        FaultSource.kinectoCheck,
        const Duration(hours: 3),
      ),
      fault(
        'F-SIM-0003',
        FaultCode.blowerCurrentSpike,
        FaultStatus.fixed,
        FaultSource.jacket,
        const Duration(days: 1),
      ),
      fault(
        'F-SIM-0002',
        FaultCode.cuffTagUnreadable,
        FaultStatus.fixed,
        FaultSource.jacket,
        const Duration(days: 14),
      ),
      fault(
        'F-SIM-0001',
        FaultCode.batteryHot,
        FaultStatus.fixed,
        FaultSource.kinectoCheck,
        const Duration(days: 16),
      ),
    ];
  }
}

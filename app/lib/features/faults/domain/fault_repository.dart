import 'fault.dart';

abstract interface class FaultRepository {
  Future<List<Fault>> fetchFaults();

  /// Throws [FaultNotFoundException] when [faultId] is unknown.
  Future<void> markResolved(String faultId);
}

class FaultNotFoundException implements Exception {
  const FaultNotFoundException(this.faultId);

  final String faultId;

  @override
  String toString() => 'FaultNotFoundException: $faultId';
}

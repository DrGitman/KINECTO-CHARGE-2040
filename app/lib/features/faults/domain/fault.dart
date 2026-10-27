enum FaultSubsystem { energy, thermal, cuff, pod }

enum FaultStatus { open, watch, fixed }

enum FaultSource { jacket, kinectoCheck }

/// Same IDs as the jacket fault_flags and the fault engine.
enum FaultCode {
  insideSensorSilent('body_sensor_offline', FaultSubsystem.thermal),
  heaterOverLimit('heater_over_limit', FaultSubsystem.thermal),
  blowerCurrentSpike('blower_current_spike', FaultSubsystem.thermal),
  bufferNotCharging('buffer_not_charging', FaultSubsystem.energy),
  batteryHot('battery_hot', FaultSubsystem.pod),
  cuffTagUnreadable('cuff_tag_unreadable', FaultSubsystem.cuff);

  const FaultCode(this.id, this.subsystem);

  final String id;
  final FaultSubsystem subsystem;

  static FaultCode? fromId(String id) {
    for (final code in values) {
      if (code.id == id) return code;
    }
    return null;
  }
}

class Fault {
  const Fault({
    required this.id,
    required this.jacketId,
    required this.code,
    required this.status,
    required this.source,
    required this.detectedAt,
  });

  final String id;
  final String jacketId;
  final FaultCode code;
  final FaultStatus status;
  final FaultSource source;
  final DateTime detectedAt;

  FaultSubsystem get subsystem => code.subsystem;
  bool get isOpen => status == FaultStatus.open;
  bool get needsAction => status != FaultStatus.fixed;

  Fault copyWith({FaultStatus? status}) => Fault(
    id: id,
    jacketId: jacketId,
    code: code,
    status: status ?? this.status,
    source: source,
    detectedAt: detectedAt,
  );
}

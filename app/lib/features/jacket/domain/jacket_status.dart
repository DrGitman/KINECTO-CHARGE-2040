import '../../comfort/domain/comfort_settings.dart';

/// Latest snapshot of the paired jacket (jacket_status), as the Virtual Lab or a real jacket reports it.
class JacketStatus {
  const JacketStatus({
    required this.jacketId,
    required this.updatedAt,
    required this.comfortBatteryPercent,
    required this.energyBufferPercent,
    required this.insideC,
    required this.cuffTagReadable,
    required this.isSimulated,
    this.outsideC,
    this.heaterOn = false,
    this.blowerOn = false,
    this.harvestedMj,
    this.activity,
    this.bufferVolts,
    this.batteryTempC,
    this.mode,
    this.faultFlags = const [],
  });

  final String jacketId;
  final DateTime updatedAt;
  final int comfortBatteryPercent;
  final int energyBufferPercent;
  // Inside microclimate, not a body reading. NaN while the inside sensor is silent.
  final double insideC;
  final bool cuffTagReadable;
  final bool isSimulated;

  final double? outsideC;
  final bool heaterOn;
  final bool blowerOn;
  final double? harvestedMj;
  final String? activity;
  final double? bufferVolts;
  final double? batteryTempC;
  // The mode the jacket is running right now (a heater fault can force it).
  final ComfortMode? mode;
  final List<String> faultFlags;
}

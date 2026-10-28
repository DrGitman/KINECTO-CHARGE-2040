/// Latest snapshot of the paired jacket, as shown on Home.
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
  });

  final String jacketId;
  final DateTime updatedAt;
  final int comfortBatteryPercent;
  final int energyBufferPercent;
  // Inside microclimate, not a body reading. NaN while the inside sensor is silent.
  final double insideC;
  final bool cuffTagReadable;
  final bool isSimulated;

  // Live readings the Virtual Lab jacket also reports; null when not known.
  final double? outsideC;
  final bool heaterOn;
  final bool blowerOn;
  final double? harvestedMj;
  final String? activity;
}

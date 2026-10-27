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
  });

  final String jacketId;
  final DateTime updatedAt;
  final int comfortBatteryPercent;
  final int energyBufferPercent;
  // Inside microclimate, not a body reading.
  final double insideC;
  final bool cuffTagReadable;
  final bool isSimulated;
}

enum ComfortMode { auto, cool, warm, off }

/// Latest snapshot of the paired jacket, as shown on Home.
class JacketStatus {
  const JacketStatus({
    required this.jacketId,
    required this.updatedAt,
    required this.comfortBatteryPercent,
    required this.energyBufferPercent,
    required this.comfortMode,
    required this.cuffTagReadable,
    required this.isSimulated,
  });

  final String jacketId;
  final DateTime updatedAt;
  final int comfortBatteryPercent;
  final int energyBufferPercent;
  final ComfortMode comfortMode;
  final bool cuffTagReadable;
  final bool isSimulated;
}

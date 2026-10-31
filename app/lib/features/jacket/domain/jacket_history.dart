enum HistoryRange { day, week, month }

/// Totals for one hour (Day) or one day (Week, Month), from jacket_samples.
class JacketBucket {
  const JacketBucket({
    required this.start,
    required this.harvestMj,
    required this.walkMinutes,
    required this.heaterMinutes,
    required this.blowerMinutes,
    this.insideC,
    this.outsideC,
    this.batteryPercent,
  });

  final DateTime start;
  final double harvestMj;
  final double walkMinutes;
  final double heaterMinutes;
  final double blowerMinutes;
  final double? insideC;
  final double? outsideC;
  final double? batteryPercent;
}

extension JacketBucketTotals on List<JacketBucket> {
  double get harvestMj => fold(0, (sum, b) => sum + b.harvestMj);
  double get walkMinutes => fold(0, (sum, b) => sum + b.walkMinutes);
  double get heaterMinutes => fold(0, (sum, b) => sum + b.heaterMinutes);
  double get blowerMinutes => fold(0, (sum, b) => sum + b.blowerMinutes);

  /// Comfort battery used per hour, from the first and last hour that have a reading.
  double? get batteryUsePerHour {
    final readings = where((b) => b.batteryPercent != null).toList();
    if (readings.length < 2) return null;
    final hours =
        readings.last.start.difference(readings.first.start).inMinutes / 60;
    final used = readings.first.batteryPercent! - readings.last.batteryPercent!;
    if (hours <= 0 || used <= 0) return null;
    return used / hours;
  }
}

enum ComfortMode { auto, cool, warm, off }

/// Time of day for the pre-warm, kept free of Flutter types.
class PrewarmTime {
  const PrewarmTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is PrewarmTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Wearer preferences, mirrors the comfort_settings table (board 11) plus mode.
class ComfortSettings {
  const ComfortSettings({
    required this.jacketId,
    required this.mode,
    required this.warmBelowC,
    required this.coolAboveC,
    required this.prewarmEnabled,
    required this.prewarmAt,
    required this.updatedAt,
    required this.isSimulated,
  });

  final String jacketId;
  final ComfortMode mode;
  final int warmBelowC;
  final int coolAboveC;
  final bool prewarmEnabled;
  final PrewarmTime prewarmAt;
  final DateTime updatedAt;
  final bool isSimulated;

  ComfortSettings copyWith({
    ComfortMode? mode,
    int? warmBelowC,
    int? coolAboveC,
    bool? prewarmEnabled,
    PrewarmTime? prewarmAt,
    DateTime? updatedAt,
  }) => ComfortSettings(
    jacketId: jacketId,
    mode: mode ?? this.mode,
    warmBelowC: warmBelowC ?? this.warmBelowC,
    coolAboveC: coolAboveC ?? this.coolAboveC,
    prewarmEnabled: prewarmEnabled ?? this.prewarmEnabled,
    prewarmAt: prewarmAt ?? this.prewarmAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isSimulated: isSimulated,
  );

  /// True when the wearer changed something the jacket has not received yet.
  bool differsFrom(ComfortSettings other) =>
      mode != other.mode ||
      warmBelowC != other.warmBelowC ||
      coolAboveC != other.coolAboveC ||
      prewarmEnabled != other.prewarmEnabled ||
      prewarmAt != other.prewarmAt;
}

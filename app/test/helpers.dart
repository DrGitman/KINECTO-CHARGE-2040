import 'package:kinecto_care/core/clock.dart';

/// Fixed time so the SIMULATED mock data and date labels are stable.
final DateTime testNow = DateTime(2026, 10, 26, 10, 42);

final fixedClockOverride = clockProvider.overrideWithValue(() => testNow);

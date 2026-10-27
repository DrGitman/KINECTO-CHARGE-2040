import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/features/comfort/domain/comfort_limits.dart';
import 'package:kinecto_care/features/comfort/domain/comfort_settings.dart';

import '../../helpers.dart';

ComfortSettings _settings({required int warm, required int cool}) =>
    ComfortSettings(
      jacketId: 'KC-SIM-0001',
      mode: ComfortMode.auto,
      warmBelowC: warm,
      coolAboveC: cool,
      prewarmEnabled: false,
      prewarmAt: const PrewarmTime(7, 30),
      updatedAt: testNow,
      isSimulated: true,
    );

void main() {
  test('thresholds stay inside the gauge scale', () {
    final atEdges = _settings(
      warm: ComfortLimits.minC,
      cool: ComfortLimits.maxC,
    );

    expect(ComfortLimits.canStepWarm(atEdges, -1), isFalse);
    expect(ComfortLimits.canStepCool(atEdges, 1), isFalse);
    expect(ComfortLimits.canStepWarm(atEdges, 1), isTrue);
  });

  test('warm and cool keep the minimum gap', () {
    final close = _settings(warm: 22, cool: 22 + ComfortLimits.minGapC);

    expect(ComfortLimits.canStepWarm(close, 1), isFalse);
    expect(ComfortLimits.canStepCool(close, -1), isFalse);
  });

  test('validate rejects settings outside the limits', () {
    expect(
      () => ComfortLimits.validate(_settings(warm: 24, cool: 25)),
      throwsA(isA<InvalidComfortSettingsException>()),
    );
    expect(
      () => ComfortLimits.validate(_settings(warm: 17, cool: 26)),
      throwsA(isA<InvalidComfortSettingsException>()),
    );
    expect(
      () => ComfortLimits.validate(_settings(warm: 19, cool: 26)),
      returnsNormally,
    );
  });
}

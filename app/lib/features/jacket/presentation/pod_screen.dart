import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../faults/domain/fault.dart';
import '../../faults/presentation/faults_controller.dart';
import '../domain/jacket_history.dart';
import 'jacket_providers.dart';

/// Comfort battery, time left and the pod checks (board 04b, Pod & battery detail).
class PodScreen extends ConsumerWidget {
  const PodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = ref.watch(jacketStatusProvider).value;
    final today = ref.watch(jacketHistoryProvider(HistoryRange.day)).value ?? const <JacketBucket>[];
    final open = ref.watch(openFaultsProvider);
    final battery = status?.comfortBatteryPercent;
    final perHour = today.batteryUsePerHour;
    final timeLeft = battery == null || perHour == null ? null : battery / perHour * 60;

    bool hasOpen(Iterable<FaultCode> codes) => open.any((f) => codes.contains(f.code));
    final checks = [
      (AppStrings.checkHeater, !hasOpen([FaultCode.heaterOverLimit, FaultCode.insideSensorSilent])),
      (AppStrings.checkFan, !hasOpen([FaultCode.blowerCurrentSpike])),
      (AppStrings.checkBuffer, !hasOpen([FaultCode.bufferNotCharging])),
      (AppStrings.checkBattery, !hasOpen([FaultCode.batteryHot])),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const PageHeader(title: AppStrings.podTitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: (battery ?? 100) < 20 ? AppColors.faultTile : AppColors.okTile,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        _Battery(percent: battery ?? 0),
                        const SizedBox(height: 14),
                        Text(
                          battery == null ? AppStrings.noReading : '$battery%',
                          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.schedule,
                            value: timeLeft == null ? AppStrings.noReading : durationLabel(timeLeft),
                            caption: AppStrings.comfortTimeLeft,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            icon: Icons.thermostat,
                            value: status?.batteryTempC == null
                                ? AppStrings.noReading
                                : '${status!.batteryTempC!.toStringAsFixed(0)} °C',
                            caption: AppStrings.batteryTemperature,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.podChecks, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final (label, ok) in checks)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(ok ? Icons.check_circle : Icons.error,
                                    size: 20, color: ok ? const Color(0xFF2EA043) : AppColors.alert),
                                const SizedBox(width: 10),
                                Expanded(child: Text(label)),
                                Text(
                                  ok ? AppStrings.ok : AppStrings.check,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ok ? const Color(0xFF2EA043) : AppColors.alert,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                    onPressed: () => context.push(AppRoutes.help),
                    child: const Text(AppStrings.openRepairCard),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    height: 96,
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.navy, width: 6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (percent.clamp(0, 100)) / 100),
                duration: const Duration(milliseconds: 700),
                builder: (context, f, _) => FractionallySizedBox(
                  widthFactor: f,
                  child: Container(
                    decoration: BoxDecoration(
                      color: percent < 20 ? AppColors.alert : const Color(0xFF2EA043),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 12,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(4)),
        ),
      ],
    ),
  );
}

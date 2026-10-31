import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../../core/widgets/tab_page.dart';
import '../domain/jacket_history.dart';
import 'jacket_providers.dart';
import 'widgets/bar_chart.dart';

/// Energy buffer and what movement harvested (board 04b, Energy detail).
class EnergyScreen extends ConsumerStatefulWidget {
  const EnergyScreen({super.key});

  @override
  ConsumerState<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends ConsumerState<EnergyScreen> {
  HistoryRange range = HistoryRange.day;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(jacketStatusProvider).value;
    final history = ref.watch(jacketHistoryProvider(range));
    final buckets = history.value ?? const <JacketBucket>[];
    final text = Theme.of(context).textTheme;

    final bars = switch (range) {
      HistoryRange.day => [
        for (var h = 7; h <= 20; h++)
          ChartBar(
            label: h.isEven ? '$h' : '',
            value: buckets.where((b) => b.start.hour == h).fold(0.0, (s, b) => s + b.harvestMj),
          ),
      ],
      _ => [
        for (final b in buckets)
          ChartBar(
            label: range == HistoryRange.week
                ? AppStrings.weekdayShort(b.start.weekday)
                : (b.start.day % 5 == 1 ? '${b.start.day}' : ''),
            value: b.harvestMj,
          ),
      ],
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: TabPage.bottomInset),
          children: [
            const PageHeader(title: AppStrings.energyTitle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TabPage.sidePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PillTabs<HistoryRange>(
                    values: HistoryRange.values,
                    selected: range,
                    label: AppStrings.rangeLabel,
                    onChanged: (r) => setState(() => range = r),
                  ),
                  const SizedBox(height: 16),
                  KcCard(
                    color: AppColors.energyTile,
                    radius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.buffer, style: text.bodyMedium?.copyWith(color: AppColors.navy)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              status == null ? AppStrings.noReading : '${status.energyBufferPercent}%',
                              style: text.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                AppStrings.harvestedIn(range, buckets.harvestMj),
                                style: text.bodyMedium?.copyWith(color: AppColors.navy),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: history.isLoading && buckets.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : BarChart(bars: bars, color: AppColors.gold, unit: 'mJ'),
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
                            icon: Icons.directions_walk,
                            value: durationLabel(buckets.walkMinutes),
                            caption: AppStrings.walkingIn(range),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            icon: Icons.bolt,
                            value: status?.bufferVolts == null
                                ? AppStrings.noReading
                                : '${status!.bufferVolts!.toStringAsFixed(2)} V',
                            caption: AppStrings.bufferVoltage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KcCard(
                    color: AppColors.okTile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.whatThisPowers,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        const SizedBox(height: 4),
                        Text(AppStrings.whatThisPowersBody,
                            style: text.bodyMedium?.copyWith(color: AppColors.navy)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

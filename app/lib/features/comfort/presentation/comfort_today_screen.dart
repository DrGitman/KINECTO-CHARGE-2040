import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../../core/widgets/tab_page.dart';
import '../../jacket/domain/jacket_history.dart';
import '../../jacket/presentation/jacket_providers.dart';
import '../../jacket/presentation/widgets/bar_chart.dart';
import 'comfort_controller.dart';
import 'comfort_copy.dart';

/// Inside vs outside today, heater and fan time, and the mode right now (board 04b, Comfort detail).
class ComfortTodayScreen extends ConsumerWidget {
  const ComfortTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = ref.watch(jacketStatusProvider).value;
    final settings = ref.watch(comfortControllerProvider).value?.saved;
    final today = ref.watch(jacketHistoryProvider(HistoryRange.day)).value ?? const <JacketBucket>[];
    final inside = ref.watch(insideReadingProvider).value;

    final hours = [for (var h = 7; h <= 20; h++) h];
    double? at(int h, double? Function(JacketBucket) pick) {
      for (final b in today) {
        if (b.start.hour == h) return pick(b);
      }
      return null;
    }

    final modeNow = status?.mode ?? settings?.mode;
    final modeLine = [
      if (modeNow != null) ComfortCopy.modeLabel(modeNow),
      inside == null ? AppStrings.insideSensorOffline : '${inside.toStringAsFixed(0)} °C ${AppStrings.insideWord}',
    ].join(' · ');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: TabPage.bottomInset),
          children: [
            PageHeader(
              title: AppStrings.comfortTitle,
              action: CircleIconButton(
                icon: Icons.tune,
                tooltip: AppStrings.openComfortButton,
                onPressed: () => context.push(AppRoutes.comfort),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TabPage.sidePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KcCard(
                    color: AppColors.comfortTile,
                    radius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.insideVsOutside,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: today.isEmpty
                              ? Center(
                                  child: Text(AppStrings.noHistoryYet,
                                      textAlign: TextAlign.center,
                                      style: text.bodySmall?.copyWith(color: AppColors.navy)),
                                )
                              : LineChart(
                                  series: [
                                    LineSeries(
                                      values: [for (final h in hours) at(h, (b) => b.insideC)],
                                      color: AppColors.navy,
                                      label: AppStrings.insideWord,
                                    ),
                                    LineSeries(
                                      values: [for (final h in hours) at(h, (b) => b.outsideC)],
                                      color: AppColors.gold,
                                      label: AppStrings.outsideWord,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const _Dot(AppColors.navy),
                            Text(' ${AppStrings.insideWord}', style: text.bodySmall?.copyWith(color: AppColors.navy)),
                            const SizedBox(width: 16),
                            const _Dot(AppColors.gold),
                            Text(' ${AppStrings.outsideWord}', style: text.bodySmall?.copyWith(color: AppColors.navy)),
                          ],
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
                          child: _TimeCard(
                            color: AppColors.energyTile,
                            icon: Icons.wb_sunny_outlined,
                            title: '${AppStrings.modeWarm} ${durationLabel(today.heaterMinutes)}',
                            caption: AppStrings.heaterToday,
                            live: status?.heaterOn ?? false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeCard(
                            color: AppColors.cuffTile,
                            icon: Icons.ac_unit,
                            title: '${AppStrings.modeCool} ${durationLabel(today.blowerMinutes)}',
                            caption: AppStrings.blowerToday,
                            live: status?.blowerOn ?? false,
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
                        Text(AppStrings.modeNow, style: text.bodyMedium),
                        const SizedBox(height: 4),
                        Text(modeLine, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        if (settings != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.yourRange(settings.warmBelowC, settings.coolAboveC),
                            style: text.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => context.push(AppRoutes.comfort),
                          child: const Text(AppStrings.changeRange),
                        ),
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

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.caption,
    required this.live,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String caption;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return KcCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: icon),
              const Spacer(),
              if (live)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                  child: Text(AppStrings.onNow,
                      style: text.labelSmall?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          Text(caption, style: text.bodySmall?.copyWith(color: AppColors.navy)),
        ],
      ),
    );
  }
}

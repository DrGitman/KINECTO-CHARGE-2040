import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/load_error_view.dart';
import '../../../core/widgets/tab_page.dart';
import '../../comfort/domain/comfort_settings.dart';
import '../../comfort/presentation/comfort_controller.dart';
import '../../comfort/presentation/comfort_copy.dart';
import '../../faults/domain/fault.dart';
import '../../faults/presentation/faults_controller.dart';
import '../../jacket/domain/jacket_status.dart';
import '../../jacket/presentation/jacket_providers.dart';
import 'widgets/comfort_battery_gauge.dart';
import 'widgets/home_header.dart';
import 'widgets/status_tile.dart';

/// Comfort battery gauge plus four tiles (board 04, screen 8).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(jacketStatusProvider);
    final openFaults = ref.watch(openFaultsProvider);
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: status.when(
        data: (jacket) => ListView(
          padding: TabPage.listPadding,
          children: [
            HomeHeader(
              now: now,
              openFaultCount: openFaults.length,
              jacketId: jacket.jacketId,
            ),
            const SizedBox(height: 12),
            _GaugeCard(jacket: jacket, now: now),
            const SizedBox(height: 12),
            _Tiles(
              jacket: jacket,
              openFaults: openFaults,
              comfortMode: ref
                  .watch(comfortControllerProvider)
                  .value
                  ?.saved
                  .mode,
            ),
            const SizedBox(height: 12),
            _LiveCard(jacket: jacket),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            LoadErrorView(onRetry: () => ref.invalidate(jacketStatusProvider)),
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.jacket, required this.now});

  final JacketStatus jacket;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(DateLabels.timeAgo(jacket.updatedAt, now), style: small),
              ],
            ),
            ComfortBatteryGauge(percent: jacket.comfortBatteryPercent),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.gaugeLow, style: small),
                Text(AppStrings.gaugeFull, style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.jacket,
    required this.openFaults,
    required this.comfortMode,
  });

  static const double _gap = 10;

  final JacketStatus jacket;
  final List<Fault> openFaults;
  final ComfortMode? comfortMode;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatusTile(
        color: AppColors.energyTile,
        icon: Icons.bolt,
        label: AppStrings.energyBufferTile,
        value: '${jacket.energyBufferPercent}%',
      ),
      StatusTile(
        color: AppColors.comfortTile,
        icon: Icons.thermostat_outlined,
        label: AppStrings.comfortTile,
        value: comfortMode == null
            ? AppStrings.noReading
            : ComfortCopy.modeLabel(comfortMode!),
        onTap: () => context.push(AppRoutes.comfort),
      ),
      StatusTile(
        color: AppColors.cuffTile,
        icon: Icons.contactless_outlined,
        label: AppStrings.cuffTagTile,
        value: jacket.cuffTagReadable
            ? AppStrings.cuffReady
            : AppStrings.cuffNeedsCheck,
      ),
      StatusTile(
        color: openFaults.isEmpty ? AppColors.okTile : AppColors.faultTile,
        icon: Icons.warning_amber_rounded,
        label: AppStrings.openFaultsTile,
        value: '${openFaults.length}',
        onTap: () => _openFaults(context),
      ),
    ];
    // Rows keep their natural height, so large system text never clips.
    return Column(
      children: [
        _row(tiles[0], tiles[1]),
        const SizedBox(height: _gap),
        _row(tiles[2], tiles[3]),
      ],
    );
  }

  Widget _row(Widget left, Widget right) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: _gap),
        Expanded(child: right),
      ],
    ),
  );

  // A single open fault opens directly, otherwise the log.
  void _openFaults(BuildContext context) {
    if (openFaults.length == 1) {
      context.push(AppRoutes.faultDetailFor(openFaults.single.id));
    } else {
      context.go(AppRoutes.faults);
    }
  }
}

/// What the jacket is doing right now, as the Virtual Lab reports it.
class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.jacket});

  final JacketStatus jacket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outside = jacket.outsideC;
    final harvested = jacket.harvestedMj;
    final rows = [
      (
        Icons.whatshot_outlined,
        AppStrings.heaterFanLabel,
        jacket.heaterOn
            ? AppStrings.heatingNow
            : jacket.blowerOn
            ? AppStrings.coolingNow
            : AppStrings.idleNow,
      ),
      (
        Icons.wb_sunny_outlined,
        AppStrings.outsideLabel,
        outside == null
            ? AppStrings.noReading
            : '${outside.toStringAsFixed(0)} °C',
      ),
      (
        Icons.bolt,
        AppStrings.harvestedLabel,
        harvested == null
            ? AppStrings.noReading
            : '${harvested.toStringAsFixed(2)} mJ',
      ),
      (
        Icons.directions_walk,
        AppStrings.activityLabel,
        _activity(jacket.activity),
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.liveFromJacket, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final (icon, label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: textTheme.bodyMedium)),
                    Text(
                      value,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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

  static String _activity(String? activity) => switch (activity) {
    null || '' => AppStrings.noReading,
    'walk' => 'Walking',
    'run' => 'Running',
    'standing' => 'Standing',
    'seated' => 'Seated',
    final String other => other,
  };
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../../core/widgets/load_error_view.dart';
import '../../../core/widgets/tab_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../comfort/presentation/comfort_controller.dart';
import '../../comfort/presentation/comfort_copy.dart';
import '../../faults/domain/fault.dart';
import '../../faults/presentation/faults_controller.dart';
import '../../jacket/domain/jacket_status.dart';
import '../../jacket/presentation/jacket_providers.dart';
import '../../notifications/notifications.dart';
import 'widgets/home_header.dart';
import 'widgets/jacket_health_gauge.dart';
import 'widgets/status_tile.dart';

/// Jacket health gauge and four tiles (board 04, Home). Everything here follows the live
/// jacket_status row, so a change in the Unity lab shows up within about a second.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(jacketStatusProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: status.when(
        data: (jacket) => ref.watch(jacketOnlineProvider)
            ? _LiveHome(jacket: jacket)
            : _OfflineHome(jacket: jacket),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => SafeArea(
          child: LoadErrorView(onRetry: () => ref.invalidate(jacketStatusProvider)),
        ),
      ),
    );
  }
}

class _LiveHome extends ConsumerWidget {
  const _LiveHome({required this.jacket});

  final JacketStatus jacket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider);
    final openFaults = ref.watch(openFaultsProvider);
    final session = ref.watch(authControllerProvider);
    final comfortMode = ref.watch(comfortControllerProvider).value?.saved.mode;
    final health = jacketHealth(
      batteryPercent: jacket.comfortBatteryPercent,
      bufferPercent: jacket.energyBufferPercent,
      openFaults: openFaults.length,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: TabPage.bottomInset),
      children: [
        HomeHeader(
          now: now,
          name: session?.greetingName ?? '',
          openFaultCount: openFaults.length,
          jacketLabel: AppStrings.pairedJacket(jacket.jacketId),
          unread: ref.watch(unreadNotificationsProvider),
          onBell: () => context.go(AppRoutes.notifications),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(TabPage.sidePadding, 16, TabPage.sidePadding, 0),
          child: Column(
            children: [
              KcCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                radius: 32,
                onTap: () => context.push(AppRoutes.pod),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _AgoPill(label: DateLabels.timeAgo(jacket.updatedAt, now)),
                        const Spacer(),
                        CircleIconButton(
                          icon: Icons.more_vert,
                          tooltip: AppStrings.jacketDetails,
                          size: 40,
                          background: Theme.of(context).colorScheme.surfaceContainerHighest,
                          onPressed: () => _showDetails(context),
                        ),
                      ],
                    ),
                    JacketHealthGauge(percent: health, caption: AppStrings.jacketHealth),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppStrings.gaugeLow, style: Theme.of(context).textTheme.bodySmall),
                        Text(AppStrings.gaugeFull, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Tiles(jacket: jacket, openFaults: openFaults, comfortModeLabel: comfortMode == null
                  ? AppStrings.noReading
                  : ComfortCopy.modeLabel(comfortMode)),
            ],
          ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, route) in [
              (Icons.battery_charging_full, AppStrings.podTitle, AppRoutes.pod),
              (Icons.bolt, AppStrings.energyTitle, AppRoutes.energy),
              (Icons.thermostat_outlined, AppStrings.comfortTitle, AppRoutes.comfortToday),
              (Icons.contactless_outlined, AppStrings.cuffTagTile, AppRoutes.cuff),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.of(sheet).pop();
                  if (route.startsWith(AppRoutes.home)) {
                    context.go(route);
                  } else {
                    context.push(route);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AgoPill extends StatelessWidget {
  const _AgoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.jacket,
    required this.openFaults,
    required this.comfortModeLabel,
  });

  static const double _gap = 10;

  final JacketStatus jacket;
  final List<Fault> openFaults;
  final String comfortModeLabel;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatusTile(
        color: AppColors.energyTile,
        icon: Icons.bolt,
        label: AppStrings.energyBufferTile,
        value: '${jacket.energyBufferPercent}%',
        onTap: () => context.go(AppRoutes.energy),
      ),
      StatusTile(
        color: AppColors.comfortTile,
        icon: Icons.thermostat_outlined,
        label: AppStrings.comfortTile,
        value: comfortModeLabel,
        onTap: () => context.go(AppRoutes.comfortToday),
      ),
      StatusTile(
        color: AppColors.cuffTile,
        icon: Icons.contactless_outlined,
        label: AppStrings.cuffTagTile,
        value: jacket.cuffTagReadable ? AppStrings.cuffReady : AppStrings.cuffNeedsCheck,
        onTap: () => context.push(AppRoutes.cuff),
      ),
      StatusTile(
        color: openFaults.isEmpty ? AppColors.okTile : AppColors.faultTile,
        icon: Icons.warning_amber_rounded,
        label: AppStrings.openFaultsTile,
        value: '${openFaults.length}',
        onTap: () => _openFaults(context),
      ),
    ];
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

/// No report for 2 minutes (board 04b, Jacket not connected).
class _OfflineHome extends ConsumerWidget {
  const _OfflineHome({required this.jacket});

  final JacketStatus jacket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final openFaults = ref.watch(openFaultsProvider);
    final health = jacketHealth(
      batteryPercent: jacket.comfortBatteryPercent,
      bufferPercent: jacket.energyBufferPercent,
      openFaults: openFaults.length,
    );
    final steps = jacket.isSimulated
        ? const [
            (Icons.play_arrow_rounded, AppStrings.reconnectUnity),
            (Icons.wifi, AppStrings.reconnectInternet),
            (Icons.power_settings_new, AppStrings.reconnectPod),
          ]
        : const [
            (Icons.bluetooth, AppStrings.reconnectBluetooth),
            (Icons.power_settings_new, AppStrings.reconnectPod),
            (Icons.contactless_outlined, AppStrings.reconnectCuff),
          ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: TabPage.listPadding,
          children: [
            Text(AppStrings.homeTab, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold),
              ),
              child: Row(
                children: [
                  Icon(jacket.isSimulated ? Icons.cloud_off : Icons.bluetooth_disabled,
                      color: const Color(0xFF8A5A00)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.jacketNotInRange,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        Text(AppStrings.lastReadingFrom(_hhmm(jacket.updatedAt)),
                            style: text.bodySmall?.copyWith(color: AppColors.navy)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KcCard(
              radius: 32,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: JacketHealthGauge(percent: health, caption: AppStrings.lastKnown, muted: true, size: 200),
              ),
            ),
            const SizedBox(height: 20),
            Text(AppStrings.howToReconnect, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final (icon, label) in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KcCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  radius: 20,
                  child: Row(
                    children: [
                      IconBubble(icon: icon, size: 36, background: AppColors.cuffTile),
                      const SizedBox(width: 14),
                      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
              onPressed: () => ref.invalidate(jacketStatusProvider),
              child: const Text(AppStrings.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

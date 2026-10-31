import 'package:flutter/material.dart';
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
import '../domain/fault.dart';
import 'fault_copy.dart';
import 'faults_controller.dart';
import 'faults_filter.dart';
import 'widgets/fault_log_entry.dart';

/// Colour-coded fault timeline with month and subsystem filters (board 04, Faults log).
class FaultsScreen extends ConsumerWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faults = ref.watch(faultsControllerProvider);
    final filter = ref.watch(faultsFilterProvider);
    final now = ref.watch(currentTimeProvider);
    final controller = ref.read(faultsFilterProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: AppStrings.faultsTab,
            showBack: false,
            action: CircleIconButton(
              icon: Icons.calendar_today_outlined,
              tooltip: AppStrings.thisMonth,
              onPressed: () => controller.showMonth(DateTime(now.year, now.month)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TabPage.sidePadding),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: ShapeDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            DateLabels.month(filter.month),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleIconButton(
                  size: 44,
                  icon: Icons.chevron_left,
                  tooltip: AppStrings.previousMonth,
                  onPressed: () => controller.shiftMonth(-1),
                ),
                const SizedBox(width: 8),
                CircleIconButton(
                  size: 44,
                  icon: Icons.chevron_right,
                  tooltip: AppStrings.nextMonth,
                  onPressed: () => controller.shiftMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: TabPage.sidePadding),
              children: [
                for (final option in <FaultSubsystem?>[null, ...FaultSubsystem.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(
                      label: option == null ? AppStrings.faultsAll : FaultCopy.subsystemLabel(option),
                      selected: option == filter.subsystem,
                      onTap: () => controller.showSubsystem(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: faults.when(
              data: (all) => _FaultList(faults: all.where(filter.accepts).toList(), now: now),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => LoadErrorView(onRetry: () => ref.invalidate(faultsControllerProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? AppColors.navy : scheme.surface,
            shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.navy : scheme.outlineVariant)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _FaultList extends StatelessWidget {
  const _FaultList({required this.faults, required this.now});

  final List<Fault> faults;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (faults.isEmpty) {
      return ListView(
        padding: TabPage.listPadding,
        children: [
          KcCard(
            color: AppColors.okTile,
            child: Column(
              children: [
                const IconBubble(icon: Icons.check, size: 56),
                const SizedBox(height: 12),
                Text(AppStrings.allClear,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        )),
                const SizedBox(height: 4),
                Text(AppStrings.noFaultsThisMonth,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.navy)),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(TabPage.sidePadding - 4, 0, TabPage.sidePadding, TabPage.bottomInset),
      itemCount: faults.length,
      itemBuilder: (context, index) => FaultLogEntry(
        fault: faults[index],
        now: now,
        isFirst: index == 0,
        isLast: index == faults.length - 1,
        onTap: () => context.push(AppRoutes.faultDetailFor(faults[index].id)),
      ),
    );
  }
}

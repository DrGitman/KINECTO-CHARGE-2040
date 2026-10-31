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
import '../domain/fault.dart';
import 'fault_copy.dart';
import 'faults_controller.dart';

/// What happened, what the jacket did, and one next step (board 04, Fault detail).
class FaultDetailScreen extends ConsumerWidget {
  const FaultDetailScreen({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faults = ref.watch(faultsControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: faults.when(
          data: (all) {
            final fault = all.where((f) => f.id == faultId).firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: AppStrings.faultTitle,
                  action: CircleIconButton(
                    icon: Icons.close,
                    tooltip: AppStrings.closeButton,
                    onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.faults),
                  ),
                ),
                Expanded(
                  child: fault == null
                      ? const Center(child: Text(AppStrings.faultNotFound))
                      : _FaultDetail(fault: fault, now: ref.watch(currentTimeProvider)),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => LoadErrorView(onRetry: () => ref.invalidate(faultsControllerProvider)),
        ),
      ),
    );
  }
}

class _FaultDetail extends ConsumerWidget {
  const _FaultDetail({required this.fault, required this.now});

  final Fault fault;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = FaultCopy.of(fault.code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _Header(fault: fault, copy: copy, now: now),
              const SizedBox(height: 12),
              _Section(title: AppStrings.whatHappened, body: copy.whatHappened),
              _Section(title: AppStrings.whatWeDid, body: copy.whatWeDid),
              _Section(title: AppStrings.whatToDo, body: copy.whatToDo),
            ],
          ),
        ),
        if (fault.needsAction)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => context.go(AppRoutes.repairs),
                  child: const Text(AppStrings.bookAFixButton),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _markResolved(context, ref),
                  child: const Text(
                    AppStrings.markResolvedButton,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _markResolved(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(faultsControllerProvider.notifier).markResolved(fault.id);
      if (context.mounted) context.pop();
    } on Exception {
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.resolveFailed)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.fault, required this.copy, required this.now});

  final Fault fault;
  final FaultCopy copy;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta = [
      FaultCopy.subsystemLabel(fault.subsystem),
      DateLabels.day(fault.detectedAt, now),
      FaultCopy.sourceLabel(fault.source),
    ].join(' · ');
    final alert = fault.isOpen ? const Color(0xFFE5383B) : AppColors.navy;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FaultStyle.tileColor(fault),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(
                icon: fault.isOpen ? Icons.warning_amber_rounded : FaultStyle.icon(fault.subsystem),
                size: 56,
                foreground: alert,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                child: Text(
                  fault.isOpen ? AppStrings.needsAFix : FaultCopy.statusLabel(fault.status),
                  style: text.labelLarge?.copyWith(color: alert, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(copy.title, style: text.titleLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(meta, style: text.bodySmall?.copyWith(color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

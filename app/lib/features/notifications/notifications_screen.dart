import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/clock.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kc_widgets.dart';
import '../../core/widgets/tab_page.dart';
import '../faults/domain/fault.dart';
import '../faults/presentation/fault_copy.dart';
import '../faults/presentation/faults_controller.dart';
import 'notifications.dart';

/// Everything that happened to the jacket, today first (board 04b, Notifications).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _seenBefore;

  @override
  void initState() {
    super.initState();
    // Keep the red dots for this visit, clear them for the next one.
    _seenBefore = ref.read(notificationsSeenProvider);
    Future.microtask(() => ref.read(notificationsSeenProvider.notifier).markAllSeen());
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(jacketEventsProvider);
    final now = ref.watch(currentTimeProvider);
    final faults = ref.watch(faultsControllerProvider).value ?? const <Fault>[];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text(AppStrings.loadFailed)),
          data: (list) {
            final today = list.where((e) => _sameDay(e.at, now)).toList();
            final earlier = list.where((e) => !_sameDay(e.at, now)).toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: TabPage.bottomInset),
              children: [
                const PageHeader(title: AppStrings.notificationsTitle),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(AppStrings.noNotifications, textAlign: TextAlign.center, style: text.bodyLarge),
                  ),
                for (final (label, group) in [(AppStrings.today, today), (AppStrings.earlier, earlier)])
                  if (group.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(label.toUpperCase(),
                          style: text.labelMedium?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w600)),
                    ),
                    for (final e in group)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(TabPage.sidePadding, 0, TabPage.sidePadding, 10),
                        child: _EventCard(
                          event: e,
                          now: now,
                          unread: _seenBefore == null || e.at.isAfter(_seenBefore!),
                          onTap: _target(e, faults),
                        ),
                      ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  VoidCallback? _target(JacketEvent e, List<Fault> faults) {
    switch (e.kind) {
      case JacketEventKind.faultOpened:
      case JacketEventKind.faultFixed:
        final fault = faults.where((f) => f.code.id == e.code).firstOrNull;
        return fault == null ? null : () => context.push(AppRoutes.faultDetailFor(fault.id));
      case JacketEventKind.comfortSynced:
        return () => context.push(AppRoutes.comfort);
      case JacketEventKind.tap:
        return () => context.push(AppRoutes.cuff);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.now, required this.unread, this.onTap});

  final JacketEvent event;
  final DateTime now;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, color, title, body) = _copy();
    final when = _sameDay(event.at, now)
        ? '${event.at.hour.toString().padLeft(2, '0')}:${event.at.minute.toString().padLeft(2, '0')}'
        : AppStrings.weekdayShort(event.at.weekday);
    return KcCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: icon, size: 48, background: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(when, style: text.labelMedium),
              const SizedBox(height: 14),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Color(0xFFE5383B), shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, Color, String, String) _copy() {
    final code = event.faultCode;
    switch (event.kind) {
      case JacketEventKind.faultOpened:
        final copy = code == null ? null : FaultCopy.of(code);
        return (
          Icons.warning_amber_rounded,
          AppColors.faultTile,
          copy?.shortTitle ?? AppStrings.faultTitle,
          copy?.whatWeDid ?? '',
        );
      case JacketEventKind.faultFixed:
        final copy = code == null ? null : FaultCopy.of(code);
        return (
          Icons.check,
          AppColors.okTile,
          AppStrings.faultFixedTitle(copy?.shortTitle ?? AppStrings.faultTitle),
          AppStrings.faultFixedBody,
        );
      case JacketEventKind.comfortSynced:
        return (
          Icons.tune,
          AppColors.comfortTile,
          AppStrings.comfortSyncedTitle,
          '${AppStrings.modeFromId(event.code)} · ${event.detail ?? ''}',
        );
      case JacketEventKind.tap:
        return (
          Icons.contactless_outlined,
          AppColors.cuffTile,
          event.code == 'OUT' ? AppStrings.tappedOut : AppStrings.tappedIn,
          event.detail ?? '',
        );
    }
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

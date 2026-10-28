import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/backend.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/load_error_view.dart';
import '../domain/app_preferences.dart';
import 'preferences_controller.dart';
import 'settings_copy.dart';
import 'widgets/settings_tile.dart';

/// One switch per alert type; safety faults cannot be turned off (board 04b, screen 32).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const Map<OptionalAlert, (IconData, Color)> _icons = {
    OptionalAlert.repairUpdates: (Icons.build_outlined, AppColors.cuffTile),
    OptionalAlert.energyTips: (Icons.bolt, AppColors.energyTile),
    OptionalAlert.comfortChanges: (Icons.thermostat, AppColors.comfortTile),
    OptionalAlert.feedbackRequests: (Icons.star_outline, AppColors.okTile),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notificationsTitle)),
      body: preferences.when(
        data: (preferences) => _AlertList(preferences: preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadErrorView(
          onRetry: () => ref.invalidate(preferencesControllerProvider),
        ),
      ),
    );
  }
}

class _AlertList extends ConsumerWidget {
  const _AlertList({required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider.notifier);
    final small = Theme.of(context).textTheme.bodySmall;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SettingsTile(
          icon: Icons.warning_amber,
          iconBackground: AppColors.faultTile,
          title: AppStrings.faultAlerts,
          subtitle: AppStrings.faultAlertsHint,
          trailing: Switch(value: true, onChanged: null),
        ),
        for (final alert in OptionalAlert.values)
          SettingsTile(
            icon: NotificationSettingsScreen._icons[alert]!.$1,
            iconBackground: NotificationSettingsScreen._icons[alert]!.$2,
            title: SettingsCopy.alertTitle(alert),
            subtitle: SettingsCopy.alertHint(alert),
            trailing: Switch(
              value: preferences.isAlertEnabled(alert),
              onChanged: (enabled) =>
                  controller.setAlertEnabled(alert, enabled),
            ),
          ),
        const SizedBox(height: 8),
        Text(AppStrings.quietHoursNote, style: small),
        const SizedBox(height: 4),
        Text(
          Backend.connected
              ? AppStrings.alertsLiveNote
              : AppStrings.alertsNotLiveNote,
          style: small,
        ),
      ],
    );
  }
}

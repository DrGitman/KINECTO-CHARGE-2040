import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pill_label.dart';
import '../../../core/widgets/tab_page.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../comfort/presentation/comfort_controller.dart';
import '../../comfort/presentation/comfort_copy.dart';
import '../../settings/presentation/preferences_controller.dart';
import '../../settings/presentation/settings_copy.dart';
import '../../settings/presentation/widgets/settings_tile.dart';
import 'sign_out_sheet.dart';

/// Same profile for students and staff, only the role badge changes (board 04, screen 15).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider)?.userId ?? '';
    final comfort = ref.watch(comfortControllerProvider).value?.saved;
    final preferences = ref.watch(preferencesControllerProvider).value;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: TabPage.listPadding,
        children: [
          Text(
            AppStrings.profileTab,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _AccountCard(userId: userId),
          const SizedBox(height: 16),
          SettingsTile(
            icon: Icons.tune,
            iconBackground: AppColors.comfortTile,
            title: AppStrings.openComfortButton,
            subtitle: comfort == null
                ? null
                : AppStrings.comfortSummary(
                    ComfortCopy.modeLabel(comfort.mode),
                    ComfortCopy.degrees(comfort.warmBelowC),
                    ComfortCopy.degrees(comfort.coolAboveC),
                  ),
            onTap: () => context.push(AppRoutes.comfort),
          ),
          SettingsTile(
            icon: Icons.notifications_none,
            iconBackground: AppColors.energyTile,
            title: AppStrings.notificationsTitle,
            subtitle: AppStrings.notificationsSummary,
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          SettingsTile(
            icon: Icons.dark_mode_outlined,
            iconBackground: AppColors.cuffTile,
            title: AppStrings.themeTitle,
            subtitle: preferences == null
                ? null
                : SettingsCopy.themeLabel(preferences.themeChoice),
            onTap: () => context.push(AppRoutes.themeSettings),
          ),
          SettingsTile(
            icon: Icons.menu_book_outlined,
            iconBackground: AppColors.okTile,
            title: AppStrings.helpTitle,
            subtitle: AppStrings.helpSummary,
            onTap: () => context.push(AppRoutes.help),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.power_settings_new),
            label: const Text(AppStrings.signOutButton),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showSignOutSheet(context);
    if (confirmed) await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.userId});

  static const double _avatarRadius = 28;

  final String userId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: _avatarRadius,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              child: Icon(Icons.person_outline),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userId,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(AppStrings.mockAccount, style: textTheme.bodySmall),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PillLabel(
                        AppStrings.roleStudent,
                        background: AppColors.cuffTile,
                      ),
                      PillLabel(
                        AppStrings.jacketPaired,
                        background: AppColors.okTile,
                      ),
                    ],
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

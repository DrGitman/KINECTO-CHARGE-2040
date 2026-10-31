import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../../core/widgets/pill_label.dart';
import '../../../core/widgets/tab_page.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../comfort/presentation/comfort_controller.dart';
import '../../comfort/presentation/comfort_copy.dart';
import '../../jacket/presentation/jacket_providers.dart';
import '../../settings/presentation/preferences_controller.dart';
import '../../settings/presentation/settings_copy.dart';
import '../../settings/presentation/widgets/settings_tile.dart';
import 'sign_out_sheet.dart';

/// The wearer from the students table, their jacket and settings (board 04, Profile).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final comfort = ref.watch(comfortControllerProvider).value?.saved;
    final preferences = ref.watch(preferencesControllerProvider).value;
    final online = ref.watch(jacketOnlineProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: TabPage.bottomInset),
        children: [
          const PageHeader(title: AppStrings.profileTab, showBack: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TabPage.sidePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session != null) _AccountCard(session: session, online: online),
                const SizedBox(height: 16),
                SettingsTile(
                  icon: Icons.tune,
                  iconBackground: AppColors.comfortTile,
                  title: AppStrings.openComfortButton,
                  subtitle: comfort == null
                      ? null
                      : AppStrings.comfortSummary(
                          ComfortCopy.modeLabel(comfort.mode),
                          '${comfort.warmBelowC}',
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
                  subtitle: preferences == null ? null : SettingsCopy.themeLabel(preferences.themeChoice),
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
                  label: const Text(AppStrings.signOutButton, style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5383B)),
                ),
              ],
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
  const _AccountCard({required this.session, required this.online});

  final AuthSession session;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return KcCard(
      radius: 28,
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            child: Text(session.initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(session.email, style: text.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const PillLabel(AppStrings.roleStudent, background: AppColors.cuffTile),
                    PillLabel(
                      online ? AppStrings.jacketPaired : AppStrings.jacketOffline,
                      background: online ? AppColors.okTile : AppColors.energyTile,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

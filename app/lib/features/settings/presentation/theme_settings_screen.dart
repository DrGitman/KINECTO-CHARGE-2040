import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/load_error_view.dart';
import '../domain/app_preferences.dart';
import 'preferences_controller.dart';
import 'widgets/settings_tile.dart';

/// Light and dark previews, match phone, larger text and reduce motion (board 04b, screen 31).
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.themeTitle)),
      body: preferences.when(
        data: (preferences) => _ThemeForm(preferences: preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadErrorView(
          onRetry: () => ref.invalidate(preferencesControllerProvider),
        ),
      ),
    );
  }
}

class _ThemeForm extends ConsumerWidget {
  const _ThemeForm({required this.preferences});

  // Turning "match my phone" off falls back to the light theme shown on the board.
  static const ThemeChoice _fallbackChoice = ThemeChoice.light;

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(preferencesControllerProvider.notifier);
    final choice = preferences.themeChoice;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _ThemePreview(
                label: AppStrings.themeLight,
                isDark: false,
                selected: choice == ThemeChoice.light,
                onTap: () => controller.setThemeChoice(ThemeChoice.light),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ThemePreview(
                label: AppStrings.themeDark,
                isDark: true,
                selected: choice == ThemeChoice.dark,
                onTap: () => controller.setThemeChoice(ThemeChoice.dark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsTile(
          icon: Icons.smartphone,
          iconBackground: AppColors.cuffTile,
          title: AppStrings.matchMyPhone,
          trailing: Switch(
            value: choice == ThemeChoice.system,
            onChanged: (enabled) => controller.setThemeChoice(
              enabled ? ThemeChoice.system : _fallbackChoice,
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.text_increase,
          iconBackground: AppColors.energyTile,
          title: AppStrings.largerText,
          trailing: Switch(
            value: preferences.largerText,
            onChanged: controller.setLargerText,
          ),
        ),
        SettingsTile(
          icon: Icons.animation,
          iconBackground: AppColors.okTile,
          title: AppStrings.reduceMotion,
          trailing: Switch(
            value: preferences.reduceMotion,
            onChanged: controller.setReduceMotion,
          ),
        ),
      ],
    );
  }
}

/// Small mock phone showing the page colour and the four pastel tiles.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.label,
    required this.isDark,
    required this.selected,
    required this.onTap,
  });

  static const double _height = 150;
  static const List<Color> _tiles = [
    AppColors.energyTile,
    AppColors.comfortTile,
    AppColors.cuffTile,
    AppColors.faultTile,
  ];

  final String label;
  final bool isDark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final page = isDark ? AppColors.pageDark : AppColors.pageLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                height: _height,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: page,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final tile in _tiles)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: tile,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

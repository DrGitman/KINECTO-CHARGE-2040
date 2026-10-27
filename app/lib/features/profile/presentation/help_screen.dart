import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../settings/presentation/widgets/settings_tile.dart';

/// Same four steps as the printed repair card (board 04b, screen 33).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AppStrings.helpTitle)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: const [
        _RepairCard(),
        SizedBox(height: 16),
        _HowItWorksTile(),
        SettingsTile(
          icon: Icons.mail_outline,
          iconBackground: AppColors.cuffTile,
          title: AppStrings.contactFabLab,
          subtitle: AppStrings.fabLabLocation,
        ),
      ],
    ),
  );
}

class _RepairCard extends StatelessWidget {
  const _RepairCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.okTile,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.repairCardTitle,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final (index, step) in AppStrings.repairCardSteps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    child: Text('${index + 1}', style: textTheme.labelSmall),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HowItWorksTile extends StatelessWidget {
  const _HowItWorksTile();

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: const ExpansionTile(
      shape: Border(),
      leading: CircleAvatar(
        backgroundColor: AppColors.comfortTile,
        foregroundColor: AppColors.navy,
        child: Icon(Icons.info_outline, size: 20),
      ),
      title: Text(
        AppStrings.howKinectoWorks,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [Text(AppStrings.howKinectoWorksBody)],
    ),
  );
}

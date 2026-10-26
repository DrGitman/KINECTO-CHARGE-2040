import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';

/// Full-screen page pushed above the tabs, with a back button (board 04, screen 9).
class ComfortScreen extends StatelessWidget {
  const ComfortScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.comfortTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.thermostat_outlined,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.comfortPlaceholder,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

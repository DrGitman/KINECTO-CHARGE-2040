import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';

/// Confirmation with Cancel as the safe default (board 04b, screen 34). Resolves to true on sign out.
Future<bool> showSignOutSheet(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SignOutSheet(),
  );
  return confirmed ?? false;
}

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new, size: 40, color: error),
            const SizedBox(height: 12),
            Text(AppStrings.signOutTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(AppStrings.signOutBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(AppStrings.cancelButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(AppStrings.signOutButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

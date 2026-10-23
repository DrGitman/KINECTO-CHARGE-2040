import 'package:flutter/material.dart';

/// Titled body for screens that are not built yet, with an optional main action.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.action,
  });

  static const double _padding = 24;

  final String title;
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            const Spacer(),
            Icon(icon, size: 48, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

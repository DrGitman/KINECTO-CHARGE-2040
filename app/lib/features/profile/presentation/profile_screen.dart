import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/placeholder_view.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlaceholderView(
    title: AppStrings.profileTab,
    icon: Icons.person_outline,
    message: AppStrings.profilePlaceholder,
    action: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.comfort),
          child: const Text(AppStrings.openComfortButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text(AppStrings.signOutButton),
        ),
      ],
    ),
  );
}

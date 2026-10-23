import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/placeholder_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: AppStrings.homeTab,
    icon: Icons.checkroom_outlined,
    message: AppStrings.homePlaceholder,
    action: FilledButton(
      onPressed: () => context.push(AppRoutes.comfort),
      child: const Text(AppStrings.openComfortButton),
    ),
  );
}

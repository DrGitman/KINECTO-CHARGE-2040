import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/widgets/placeholder_view.dart';

class FaultsScreen extends StatelessWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderView(
    title: AppStrings.faultsTab,
    icon: Icons.show_chart,
    message: AppStrings.faultsPlaceholder,
  );
}

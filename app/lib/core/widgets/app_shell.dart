import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/faults/domain/fault.dart';
import '../../features/faults/presentation/fault_copy.dart';
import '../../features/faults/presentation/faults_controller.dart';
import '../app_strings.dart';
import '../router/app_routes.dart';
import 'floating_tab_bar.dart';

/// Floating tab bar around the signed-in tabs. Order must match the router branches.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<FloatingTabItem> tabs = [
    FloatingTabItem(AppStrings.homeTab, Icons.home_outlined),
    FloatingTabItem(AppStrings.faultsTab, Icons.show_chart),
    FloatingTabItem(AppStrings.repairsTab, Icons.build_outlined),
    FloatingTabItem(AppStrings.profileTab, Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fault alerts are always on: a fault the jacket raises while the app is open pops up on any tab.
    ref.listen(faultsControllerProvider, (previous, next) {
      final before = previous?.value;
      final now = next.value;
      if (before == null || now == null) return;
      final known = {for (final fault in before) fault.id};
      final opened = now.where((f) => f.isOpen && !known.contains(f.id));
      if (opened.isNotEmpty) _alert(context, opened.first);
    });
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingTabBar(
        items: tabs,
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }

  static void _alert(BuildContext context, Fault fault) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.newFaultAlert(FaultCopy.of(fault.code).shortTitle),
        ),
        action: SnackBarAction(
          label: AppStrings.viewFaultButton,
          onPressed: () => context.push(AppRoutes.faultDetailFor(fault.id)),
        ),
      ),
    );
  }
}

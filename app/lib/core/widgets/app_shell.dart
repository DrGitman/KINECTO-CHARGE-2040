import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_strings.dart';
import 'floating_tab_bar.dart';

/// Floating tab bar around the signed-in tabs. Order must match the router branches.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<FloatingTabItem> tabs = [
    FloatingTabItem(AppStrings.homeTab, Icons.home_outlined),
    FloatingTabItem(AppStrings.faultsTab, Icons.show_chart),
    FloatingTabItem(AppStrings.repairsTab, Icons.build_outlined),
    FloatingTabItem(AppStrings.profileTab, Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
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
}

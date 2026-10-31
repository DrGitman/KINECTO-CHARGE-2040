import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kc_widgets.dart';

/// Navy top with the logo, greeting, bell and one hero line driven by open faults (board 04, Home).
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.now,
    required this.name,
    required this.openFaultCount,
    required this.jacketLabel,
    required this.unread,
    required this.onBell,
  });

  static const int _afternoonFromHour = 12;
  static const int _eveningFromHour = 18;

  final DateTime now;
  final String name;
  final int openFaultCount;
  final String jacketLabel;
  final int unread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF253D5E),
                  shape: BoxShape.circle,
                ),
                child: const LogoMark(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleIconButton(
                    icon: Icons.notifications_none,
                    tooltip: AppStrings.notificationsTitle,
                    onPressed: onBell,
                    background: const Color(0xFF253D5E),
                    foreground: Colors.white,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5383B),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.navy, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              heroLine(openFaultCount),
              key: ValueKey(openFaultCount),
              style: text.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const ShapeDecoration(
              color: Color(0xFF253D5E),
              shape: StadiumBorder(),
            ),
            child: Text(
              jacketLabel,
              style: text.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String heroLine(int openFaultCount) => switch (openFaultCount) {
    0 => AppStrings.heroAllGood,
    1 => AppStrings.heroOneFault,
    _ => AppStrings.heroFaults(openFaultCount),
  };

  String _greeting() {
    if (now.hour < _afternoonFromHour) return AppStrings.greetingMorning;
    if (now.hour < _eveningFromHour) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }
}

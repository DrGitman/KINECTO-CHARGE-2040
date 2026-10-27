import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// White card row with a pastel icon, used by Profile and the settings pages.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  static const double _iconSize = 40;

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: _iconSize,
        height: _iconSize,
        decoration: BoxDecoration(
          color: iconBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.navy),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    ),
  );
}

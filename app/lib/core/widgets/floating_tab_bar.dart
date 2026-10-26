import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FloatingTabItem {
  const FloatingTabItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Dark floating tab bar; the active tab grows into a white pill with its label (board 06).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const Duration pillDuration = Duration(milliseconds: 250);
  static const double _barHeight = 64;
  static const double _barPadding = 8;
  static const double _sideMargin = 16;
  static const double _bottomMargin = 12;

  final List<FloatingTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        _sideMargin,
        0,
        _sideMargin,
        _bottomMargin,
      ),
      child: Container(
        height: _barHeight,
        padding: const EdgeInsets.all(_barPadding),
        decoration: const ShapeDecoration(
          color: AppColors.tabBar,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              _TabButton(
                item: items[i],
                isSelected: i == currentIndex,
                duration: reduceMotion ? Duration.zero : pillDuration,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.isSelected,
    required this.duration,
    required this.onTap,
  });

  // 48 px minimum touch target (Fitts's law, board 07).
  static const double _targetSize = 48;
  static const double _labelGap = 8;
  static const double _pillPadding = 16;

  final FloatingTabItem item;
  final bool isSelected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.navy : AppColors.tabPill;
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeInOut,
            constraints: const BoxConstraints(
              minWidth: _targetSize,
              minHeight: _targetSize,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? _pillPadding : 0,
            ),
            decoration: ShapeDecoration(
              color: isSelected ? AppColors.tabPill : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: AnimatedSize(
              duration: duration,
              curve: Curves.easeInOut,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: foreground),
                  if (isSelected) ...[
                    const SizedBox(width: _labelGap),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

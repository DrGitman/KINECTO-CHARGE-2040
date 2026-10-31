import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// Building blocks shared by the screens on App Design boards 04 and 04b.

/// Gold ring and red plug (board 01).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo.svg',
    width: size,
    height: size,
    semanticsLabel: 'Kinecto Care',
  );
}

/// White circle with one icon: back, close, filters, calendar.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 48,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? scheme.surface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 22, color: foreground ?? scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Back circle, big title, optional circle action on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.action,
  });

  final String title;
  final bool showBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Row(
      children: [
        if (showBack) ...[
          CircleIconButton(
            icon: Icons.chevron_left,
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

/// Rounded card in a solid colour (white by default).
class KcCard extends StatelessWidget {
  const KcCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// White (or tinted) circle holding a navy icon, as on the tiles.
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.size = 40,
    this.background = Colors.white,
    this.foreground = AppColors.navy,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, size: size * 0.5, color: foreground),
  );
}

/// Day / Week / Month style pill tabs.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 44,
              decoration: ShapeDecoration(
                color: values[i] == selected ? AppColors.navy : scheme.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: values[i] == selected
                        ? AppColors.navy
                        : scheme.outlineVariant,
                  ),
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(values[i]),
                child: Center(
                  child: Text(
                    label(values[i]),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: values[i] == selected
                          ? Colors.white
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A big number with a small caption under it ("2 h 10 m / walking today").
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    this.color,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = color == null ? null : AppColors.navy;
    return KcCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: ink),
          const SizedBox(height: 24),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          Text(caption, style: text.bodySmall?.copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// "2 h 10 m", "42 min", "--".
String durationLabel(double minutes) {
  if (minutes.isNaN || minutes <= 0) return '0 min';
  final m = minutes.round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} m';
}

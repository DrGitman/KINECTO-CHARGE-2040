import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/notifications.dart';
import 'jacket_providers.dart';

/// Is the cuff tag readable, and the last time it was used at a door (board 04b, Cuff tag detail).
class CuffTagScreen extends ConsumerStatefulWidget {
  const CuffTagScreen({super.key});

  @override
  ConsumerState<CuffTagScreen> createState() => _CuffTagScreenState();
}

class _CuffTagScreenState extends ConsumerState<CuffTagScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _ripple.repeat();
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = ref.watch(jacketStatusProvider).value;
    final now = ref.watch(currentTimeProvider);
    final session = ref.watch(authControllerProvider);
    final events = ref.watch(jacketEventsProvider).value ?? const <JacketEvent>[];
    final lastTap = events.where((e) => e.kind == JacketEventKind.tap).firstOrNull;
    final readable = status?.cuffTagReadable ?? true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ripple.stop();
    } else if (!_ripple.isAnimating) {
      _ripple.repeat();
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const PageHeader(title: AppStrings.cuffTagTile),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 230,
                    decoration: BoxDecoration(
                      color: readable ? AppColors.cuffTile : AppColors.faultTile,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: AnimatedBuilder(
                      animation: _ripple,
                      builder: (context, _) => CustomPaint(
                        painter: _RipplePainter(_ripple.value),
                        child: Center(
                          child: IconBubble(
                            icon: Icons.contactless_outlined,
                            size: 48,
                            background: AppColors.navy,
                            foreground: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    readable ? AppStrings.tagReadable : AppStrings.tagNotReadable,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (status != null) AppStrings.lastChecked(DateLabels.timeAgo(status.updatedAt, now)),
                      if (session != null && session.tagId.isNotEmpty) session.tagId,
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                  if (lastTap != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.lastTapLine(lastTap.code ?? '', lastTap.detail ?? '', DateLabels.day(lastTap.at, now)),
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  KcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.whatTheTagDoes,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(AppStrings.whatTheTagDoesBody, style: text.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _test(context, readable),
                    child: const Text(AppStrings.testMyTag),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The jacket checks its tag on every report, so the answer is the latest reading.
  void _test(BuildContext context, bool readable) {
    ref.invalidate(jacketStatusProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(readable ? AppStrings.tagTestOk : AppStrings.tagTestFailed)),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 1 - p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(c, 30 + p * 70, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';

/// Six boxes for the code (board 04, Verify code). Email delivery is not connected in this
/// prototype, so the code Kinecto made is shown on the screen.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.email, required this.code});

  final String email;
  final String code;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  static const int _resendAfter = 45;

  final _input = TextEditingController();
  final _focus = FocusNode();
  late String _code = widget.code;
  int _secondsLeft = _resendAfter;
  Timer? _timer;
  bool _checking = false;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      setState(() => _wrong = false);
      if (_input.text.length == 6) _verify();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _resendAfter;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_checking || _input.text.length != 6) return;
    setState(() => _checking = true);
    try {
      // Success: the router leaves sign-in by itself once the session is set.
      await ref.read(authControllerProvider.notifier).verifyCode(widget.email, _input.text);
    } on AuthException {
      if (mounted) setState(() => _wrong = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      final code = await ref.read(authControllerProvider.notifier).requestCode(widget.email);
      if (!mounted) return;
      setState(() => _code = code);
      _input.clear();
      _startTimer();
    } on AuthException {
      // The email worked a moment ago; nothing new to show.
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final digits = _input.text.split('');
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: ''),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                children: [
                  const Center(
                    child: IconBubble(icon: Icons.mail_outline, size: 108, background: AppColors.cuffTile),
                  ),
                  const SizedBox(height: 24),
                  Text(AppStrings.checkYourEmail,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${AppStrings.weSentCode}\n${widget.email}',
                      textAlign: TextAlign.center, style: text.bodyMedium),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: Stack(
                      children: [
                        // The real field is invisible; the six boxes show what was typed.
                        Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _input,
                            focusNode: _focus,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < 6; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 48,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    width: 2,
                                    color: _wrong
                                        ? const Color(0xFFE5383B)
                                        : i == digits.length
                                        ? AppColors.gold
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  i < digits.length ? digits[i] : '',
                                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_wrong)
                    Text(AppStrings.signInProblem(AuthProblem.wrongCode),
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(color: const Color(0xFFE5383B), fontWeight: FontWeight.w600)),
                  Center(
                    child: _secondsLeft > 0
                        ? Text(AppStrings.resendIn(_secondsLeft), style: text.bodyMedium)
                        : TextButton(onPressed: _resend, child: const Text(AppStrings.resendCode)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.energyTile,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      AppStrings.demoCode(_code),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              child: FilledButton(
                onPressed: _input.text.length == 6 && !_checking ? _verify : null,
                child: _checking
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Text(AppStrings.verify),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

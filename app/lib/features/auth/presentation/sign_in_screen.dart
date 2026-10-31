import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kc_widgets.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';

/// NUST email first, then a 6-digit code (board 04, Sign in and Sign in · error).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  bool _sending = false;
  AuthProblem? _problem;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() => _problem = null));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!isNustEmail(email)) {
      setState(() => _problem = AuthProblem.notNust);
      return;
    }
    setState(() => _sending = true);
    try {
      final code = await ref.read(authControllerProvider.notifier).requestCode(email);
      if (!mounted) return;
      context.push(AppRoutes.verifyCode, extra: (email: email, code: code));
    } on AuthException catch (error) {
      if (mounted) setState(() => _problem = error.problem);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valid = isNustEmail(_email.text);
    final error = _problem;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(color: Color(0xFF16355E), shape: BoxShape.circle),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(28, MediaQuery.paddingOf(context).top + 48, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LogoMark(size: 64),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.signInTitle,
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                  children: [
                    Text(AppStrings.signInWithNust, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(AppStrings.signInBody, style: text.bodyMedium),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: AppStrings.emailHint,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: const Icon(Icons.mail_outline),
                        suffixIcon: valid
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFF2EA043),
                                  child: Icon(Icons.check, size: 16, color: Colors.white),
                                ),
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: error != null ? const Color(0xFFE5383B) : AppColors.navy,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: error != null ? const Color(0xFFE5383B) : AppColors.navy,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error == null ? AppStrings.nustOnly : AppStrings.signInProblem(error),
                      style: text.bodySmall?.copyWith(
                        color: error == null ? null : const Color(0xFFE5383B),
                        fontWeight: error == null ? null : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                          : const Text(AppStrings.sendMyCode),
                    ),
                    const SizedBox(height: 16),
                    Text(AppStrings.emailUse, textAlign: TextAlign.center, style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

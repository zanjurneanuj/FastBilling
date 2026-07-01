import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_strings.dart';
import '../../viewmodels/auth_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    await vm.signInWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (vm.status == AuthStatus.success) context.go('/home');
  }

  Future<void> _googleSignIn(AuthViewModel vm) async {
    await vm.signInWithGoogle();
    if (!mounted) return;
    if (vm.status == AuthStatus.success) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthViewModel>(
          builder: (context, vm, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    _AppIcon(),
                    const SizedBox(height: 28),

                    Text(
                      AppStrings.welcomeBack,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    _SubtitleText(AppStrings.loginSubtitle),
                    const SizedBox(height: 36),

                    _FieldLabel(AppStrings.emailLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: AppStrings.emailHint,
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return AppStrings.emailRequired;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                          return AppStrings.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel(AppStrings.passwordLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: vm.obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(vm),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            vm.obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary(context),
                            size: 20,
                          ),
                          onPressed: vm.togglePasswordVisibility,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return AppStrings.passwordRequired;
                        if (v.length < 6) return AppStrings.passwordMinLen;
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPassword(context, vm),
                        child: const Text(AppStrings.forgotPassword,
                            style: TextStyle(color: AppColors.primary,
                                fontWeight: FontWeight.w500, fontSize: 13)),
                      ),
                    ),

                    if (vm.status == AuthStatus.error && vm.errorMsg.isNotEmpty)
                      _ErrorBanner(vm.errorMsg),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: vm.isLoading ? null : () => _submit(vm),
                        child: vm.isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Text(AppStrings.signIn),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _OrDivider(),
                    const SizedBox(height: 20),

                    _GoogleButton(
                      loading: vm.isLoading,
                      onTap: () => _googleSignIn(vm),
                    ),
                    const SizedBox(height: 48),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppStrings.newHere,
                              style: TextStyle(
                                  color: AppColors.textSecondary(context), fontSize: 14)),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(left: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(AppStrings.createAccount,
                                style: TextStyle(color: AppColors.primary,
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Forgot password bottom sheet
  void _showForgotPassword(BuildContext context, AuthViewModel vm) {
    final ctrl    = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Reset Password',
                  style: TextStyle(color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text('Enter your email to receive a reset link.',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 20),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your email' : null,
              ),
              const SizedBox(height: 20),
              // Show success/error from vm
              if (vm.resetEmailSent)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.paid,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.check_circle_outline, color: AppColors.paidText, size: 16),
                    SizedBox(width: 8),
                    Text('Reset link sent! Check your email.',
                        style: TextStyle(color: AppColors.paidText, fontSize: 13)),
                  ]),
                )
              else
                ElevatedButton(
                  onPressed: vm.isLoading ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    await vm.sendPasswordReset(ctrl.text.trim());
                  },
                  child: vm.isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Send Reset Link'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets (unchanged) ──────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14)),
    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
  );
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    const colored = 'your invoices.';
    final plain = text.replaceAll(colored, '');
    return RichText(text: TextSpan(
      style: const TextStyle(fontSize: 15, height: 1.4),
      children: [
        TextSpan(text: plain, style: TextStyle(color: AppColors.textSecondary(context))),
        const TextSpan(text: colored, style: TextStyle(color: AppColors.primary)),
      ],
    ));
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.overdue, borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.overdueText, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
          style: const TextStyle(color: AppColors.overdueText, fontSize: 13))),
    ]),
  );
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: AppColors.border(context))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(AppStrings.orDivider,
            style: TextStyle(color: AppColors.textHint(context), fontSize: 13))),
    Expanded(child: Divider(color: AppColors.border(context))),
  ]);
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: OutlinedButton(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: AppColors.textPrimary(context)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4))),
        const SizedBox(width: 10),
        Text(AppStrings.continueGoogle, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context))),
      ]),
    ),
  );
}
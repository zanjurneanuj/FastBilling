import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    await vm.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (vm.status == AuthStatus.success) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface(context),
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

                    // Back button
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.background(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: AppColors.textPrimary(context)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App icon
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 20),

                    Text('Create account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w700,
                            )),
                    const SizedBox(height: 6),
                    RichText(text: TextSpan(
                      style: const TextStyle(fontSize: 15, height: 1.4),
                      children: [
                        TextSpan(text: 'Start managing ',
                            style: TextStyle(color: AppColors.textSecondary(context))),
                        const TextSpan(text: 'your invoices.',
                            style: TextStyle(color: AppColors.primary)),
                      ],
                    )),
                    const SizedBox(height: 32),

                    // Name
                    _Label('Full Name'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Aarav Sharma',
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _Label('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _Label('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: vm.obscurePassword,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Min. 6 characters',
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            vm.obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary(context), size: 20,
                          ),
                          onPressed: vm.togglePasswordVisibility,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _Label('Confirm Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: vm.obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(vm),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Re-enter password',
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            color: AppColors.textSecondary(context), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            vm.obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary(context), size: 20,
                          ),
                          onPressed: vm.toggleConfirmVisibility,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your password';
                        if (v != _passCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Error
                    if (vm.status == AuthStatus.error && vm.errorMsg.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.overdue,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.overdueText, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(vm.errorMsg,
                              style: const TextStyle(
                                  color: AppColors.overdueText, fontSize: 13))),
                        ]),
                      ),

                    const SizedBox(height: 8),

                    // Register button
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: vm.isLoading ? null : () => _submit(vm),
                        child: vm.isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Already have account
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account?',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context), fontSize: 14)),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(left: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Sign in',
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
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.primary,
          fontSize: 13, fontWeight: FontWeight.w500));
}
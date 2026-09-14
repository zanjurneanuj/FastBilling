import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/PaymentService.dart';
import '../../services/SubscriptionService.dart';
import '../../utils/app_colors.dart';

/// Paywall / plan screen. Reachable both when a user is actually blocked
/// (out of free invoices) and voluntarily from the "Free plan" card in
/// Settings — copy adapts to which case it is. The "Upgrade" button opens
/// a real Razorpay checkout (see [PaymentService] for the demo-key note);
/// until a real key is configured it falls back to a "coming soon" message
/// instead of launching a checkout that would just show Razorpay's own
/// "invalid key" error.
class UpgradeView extends StatefulWidget {
  const UpgradeView({super.key});

  @override
  State<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends State<UpgradeView> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final used = SubscriptionService.invoiceCount;
    final limit = SubscriptionService.freeInvoiceLimit;
    final remaining = SubscriptionService.remainingFree;
    final isPremium = SubscriptionService.isPremium;
    final atLimit = !isPremium && remaining <= 0;

    final String headline;
    final String body;
    if (isPremium) {
      headline = "You're on the Premium plan";
      body = 'Enjoy unlimited invoices and PDF exports.';
    } else if (atLimit) {
      headline = "You've used all $limit free invoices";
      body = 'Upgrade to keep creating invoices — your existing $used '
          'invoices and their PDFs stay fully accessible either way.';
    } else {
      headline = '$remaining of $limit free invoices left';
      body = 'You can upgrade any time for unlimited invoices — no rush.';
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textPrimary(context)),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 14,
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              _Benefit(icon: Icons.all_inclusive_rounded, text: 'Unlimited invoices'),
              const SizedBox(height: 14),
              _Benefit(icon: Icons.picture_as_pdf_outlined, text: 'Unlimited PDF exports & sharing'),
              const SizedBox(height: 14),
              _Benefit(icon: Icons.support_agent_rounded, text: 'Priority support'),
              const Spacer(),
              if (!isPremium) ...[
                Text(
                  '${PaymentService.premiumAmountLabel} · one-time',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _processing ? null : _startUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Upgrade',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Text(isPremium ? 'Done' : 'Maybe later',
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startUpgrade() {
    if (!PaymentService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Upgrades aren't open yet — we'll notify you as soon as they are."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _processing = true);
    PaymentService.startCheckout(
      onSuccess: () {
        if (!mounted) return;
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You're upgraded! Enjoy unlimited invoices."),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text,
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    ],
  );
}

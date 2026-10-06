import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/PaymentService.dart';
import '../../services/SubscriptionService.dart';
import '../../utils/app_colors.dart';

/// Premium plans page: why it's worth it, Free vs Premium, and the four
/// prepaid plans (1 / 3 / 6 / 12 months) paid through Razorpay. Reachable
/// when blocked by the free limit, from Settings, and from locked Pro
/// templates; copy adapts to which case it is.
class UpgradeView extends StatefulWidget {
  const UpgradeView({super.key});

  @override
  State<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends State<UpgradeView> {
  PremiumPlan _plan = PaymentService.plans[2]; // 6 months
  bool _processing = false;

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  void _pay() {
    setState(() => _processing = true);
    PaymentService.startCheckout(
      plan: _plan,
      onSuccess: () {
        if (!mounted) return;
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Premium active until '
              '${DateFormat('d MMM yyyy').format(SubscriptionService.premiumUntil ?? DateTime.now())}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ));
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = SubscriptionService.isPremium;
    final atLimit = !isPremium && SubscriptionService.remainingFree <= 0;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(onClose: _close, atLimit: atLimit)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList.list(children: [
              _Title('Why businesses upgrade'),
              const SizedBox(height: 12),
              const _WhyGrid(),
              const SizedBox(height: 24),
              _Title('Free vs Premium'),
              const SizedBox(height: 12),
              const _CompareTable(),
              const SizedBox(height: 24),
              _Title(isPremium ? 'Extend your plan' : 'Choose your plan'),
              const SizedBox(height: 4),
              Text(
                isPremium
                    ? 'Renewing early adds the new period on top of your remaining time.'
                    : 'Prepaid — no auto-debit, no surprise charges.',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final p in PaymentService.plans) ...[
                _PlanCard(
                  plan: p,
                  selected: p.id == _plan.id,
                  onTap: () => setState(() => _plan = p),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              _Title('Questions'),
              const SizedBox(height: 4),
              const _Faq(
                q: 'Will I be charged automatically?',
                a: 'No. Each plan is a one-time prepaid payment. We remind you in the app before it ends, and you renew only if you want to.',
              ),
              const _Faq(
                q: 'What happens when my plan ends?',
                a: 'Nothing is deleted. All invoices and PDFs stay accessible; new invoices go back to the free limit and Pro templates fall back to a free one until you renew.',
              ),
              const _Faq(
                q: 'Is payment secure?',
                a: 'Payments are handled by Razorpay (UPI, cards, net banking, wallets). Fast Billing never sees your card or UPI PIN.',
              ),
              const SizedBox(height: 140),
            ]),
          ),
        ],
      ),
      ),
      bottomSheet: _PayBar(
        plan: _plan,
        processing: _processing,
        renewing: isPremium,
        onPay: _pay,
        onLater: _close,
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.onClose, required this.atLimit});
  final VoidCallback onClose;
  final bool atLimit;

  @override
  Widget build(BuildContext context) {
    final isPremium = SubscriptionService.isPremium;
    final until = SubscriptionService.premiumUntil;
    final plan = PaymentService.planById(SubscriptionService.planId);

    final String status;
    if (isPremium) {
      status = until == null
          ? 'Premium active'
          : 'Premium${plan != null ? ' · ${plan.title}' : ''} · active until ${DateFormat('d MMM yyyy').format(until)}';
    } else if (SubscriptionService.isExpired) {
      status = 'Your Premium plan has ended — renew to continue';
    } else if (atLimit) {
      status = "You've used all ${SubscriptionService.invoiceLimit} free invoices";
    } else {
      status = '${SubscriptionService.remainingFree} of '
          '${SubscriptionService.invoiceLimit} free invoices left';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16255C), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: onClose,
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFC155), Color(0xFFF7931E)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fast Billing Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Look professional. Get paid faster.',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium ? Icons.verified_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Why upgrade ──────────────────────────────────────────────────────────────

class _WhyGrid extends StatelessWidget {
  const _WhyGrid();

  static const _items = [
    (Icons.all_inclusive_rounded, 'Unlimited invoices',
        'No 10-invoice cap, and unlimited saved clients & items.'),
    (Icons.auto_awesome_rounded, '5 Pro templates',
        'Midnight, Edge, Crimson & more designs that stand out.'),
    (Icons.brush_rounded, 'Your own templates',
        'Pick a layout and brand colour and save it as yours.'),
    (Icons.speed_rounded, 'Get paid faster',
        'Polished GST invoices with UPI QR get settled sooner.'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        for (final (icon, title, body) in _items)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 10),
                Text(title,
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(body,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11.5,
                          height: 1.3)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Free vs Premium ─────────────────────────────────────────────────────────

class _CompareTable extends StatelessWidget {
  const _CompareTable();

  static const _rows = <(String, Object, Object)>[
    ('Invoices', '10 total', 'Unlimited'),
    ('Saved clients', '10', 'Unlimited'),
    ('Saved items', '10', 'Unlimited'),
    ('GST invoice, HSN, CGST/SGST/IGST', true, true),
    ('UPI QR, attachments, PAID stamp', true, true),
    ('Drag & drop invoice sections', true, true),
    ('10 free templates', true, true),
    ('5 Pro templates', false, true),
    ('Create your own templates', false, true),
    ('Priority support', false, true),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(Object v, {bool premium = false}) {
      if (v is bool) {
        return Icon(
          v ? Icons.check_circle_rounded : Icons.remove_rounded,
          size: 18,
          color: v
              ? (premium ? AppColors.primary : AppColors.success)
              : AppColors.textHint(context),
        );
      }
      return Text('$v',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: premium ? AppColors.primary : AppColors.textSecondary(context)));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.3),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppColors.background(context)),
            children: [
              const SizedBox(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
          for (final (label, free, premium) in _rows)
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border(context))),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Text(label,
                      style: TextStyle(
                          color: AppColors.textPrimary(context), fontSize: 12.5)),
                ),
                Center(child: cell(free)),
                Center(child: cell(premium, premium: true)),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Plans ────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});
  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textHint(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(plan.title,
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    if (plan.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFFC155), Color(0xFFF7931E)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(plan.badge!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    plan.months == 1
                        ? 'Billed every month you renew'
                        : '${plan.perMonthLabel} · save ${plan.savingPercent}%',
                    style: TextStyle(
                        color: plan.months == 1
                            ? AppColors.textSecondary(context)
                            : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(plan.priceLabel,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.plan,
    required this.processing,
    required this.renewing,
    required this.onPay,
    required this.onLater,
  });
  final PremiumPlan plan;
  final bool processing;
  final bool renewing;
  final VoidCallback onPay;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: processing ? null : onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      '${renewing ? 'Extend' : 'Get Premium'} · ${plan.priceLabel} for ${plan.title.toLowerCase()}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 12, color: AppColors.textHint(context)),
              const SizedBox(width: 4),
              Text('Secured by Razorpay',
                  style: TextStyle(color: AppColors.textHint(context), fontSize: 11)),
              TextButton(
                onPressed: onLater,
                child: Text('Maybe later',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 17,
          fontWeight: FontWeight.w800));
}

class _Faq extends StatelessWidget {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(q,
          style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      children: [
        Text(a,
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 13, height: 1.4)),
      ],
    ),
  );
}

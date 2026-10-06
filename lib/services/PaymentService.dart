import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'auth_service.dart';
import 'SubscriptionService.dart';

/// One Premium billing period.
class PremiumPlan {
  final String id;
  final String title;
  final int months;
  final int pricePaise;
  final String? badge;

  const PremiumPlan({
    required this.id,
    required this.title,
    required this.months,
    required this.pricePaise,
    this.badge,
  });

  int get priceRupees => pricePaise ~/ 100;
  String get priceLabel => '₹$priceRupees';
  String get perMonthLabel => '₹${(priceRupees / months).round()}/mo';

  /// Saving versus paying monthly for the same period, in percent.
  int get savingPercent {
    final monthly = PaymentService.plans.first.priceRupees * months;
    return monthly == 0 ? 0 : ((1 - priceRupees / monthly) * 100).round();
  }
}

/// Razorpay checkout for Premium — unlimited invoices, Pro templates and
/// custom templates.
///
/// TEST MODE: [_keyId] is a `rzp_test_` key, so checkout runs against
/// Razorpay's sandbox — use test cards / `success@razorpay` UPI, no real
/// money moves. Swap in a `rzp_live_` key to go live.
///
/// Plans are prepaid periods: each payment extends `premiumUntil`. True
/// auto-debit needs Razorpay Subscriptions (plan + subscription created
/// server-side with the key *secret*, which must never be in the APK) plus
/// a webhook; until that backend exists the client-side success callback
/// is trusted — fine for a demo, spoofable by a modified client.
class PaymentService {
  PaymentService._();

  static const String _keyId = 'rzp_test_TkaIO5Zrtc0Xue';

  static bool get isConfigured => !_keyId.contains('REPLACE_WITH');
  static bool get isTestMode => _keyId.startsWith('rzp_test_');

  /// Ledger of every checkout outcome — success, failed, cancelled.
  static const paymentsCollection = 'payments';

  static const plans = <PremiumPlan>[
    PremiumPlan(id: 'monthly', title: 'Monthly', months: 1, pricePaise: 9900),
    PremiumPlan(id: 'quarterly', title: '3 Months', months: 3, pricePaise: 26900),
    PremiumPlan(
        id: 'half_yearly',
        title: '6 Months',
        months: 6,
        pricePaise: 49900,
        badge: 'Most popular'),
    PremiumPlan(
        id: 'yearly',
        title: 'Yearly',
        months: 12,
        pricePaise: 89900,
        badge: 'Best value'),
  ];

  static PremiumPlan? planById(String? id) =>
      plans.where((p) => p.id == id).firstOrNull;

  static Razorpay? _razorpay;

  static void startCheckout({
    required PremiumPlan plan,
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) {
    final user = AuthService.currentUser;

    _dispose(); // never leave two checkouts listening
    final razorpay = Razorpay();
    _razorpay = razorpay;
    final openedAt = DateTime.now();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _handleSuccess(plan, r, onSuccess, onError);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
      // Failed and abandoned checkouts are recorded too — useful for
      // support ("I paid but…") and for spotting checkout problems.
      _recordAttempt(plan, {
        'status': cancelled ? 'cancelled' : 'failed',
        'errorCode': r.code,
        'errorMessage': r.message,
        'checkoutOpenedAt': Timestamp.fromDate(openedAt),
      });
      onError(cancelled
          ? 'Payment cancelled — nothing was charged.'
          : (r.message ?? 'Payment failed. Please try again.'));
      _dispose();
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // User picked a wallet app instead of completing in-checkout —
      // not a failure, just log it; Razorpay handles the redirect.
      debugPrint('[Payment] external wallet selected: ${r.walletName}');
    });

    razorpay.open({
      'key': _keyId,
      'amount': plan.pricePaise,
      'currency': 'INR',
      'name': 'Fast Billing',
      'description': 'Premium · ${plan.title}',
      'notes': {'plan': plan.id, 'uid': user?.uid ?? ''},
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
      },
      'theme': {'color': '#4F46E5'},
    });
  }

  /// Fields every ledger entry carries.
  static Future<Map<String, Object?>> _baseRecord(PremiumPlan plan) async {
    final user = AuthService.currentUser;
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return {
      'uid': user?.uid,
      'email': user?.email,
      'plan': plan.id,
      'planTitle': plan.title,
      'months': plan.months,
      'amountPaise': plan.pricePaise,
      'currency': 'INR',
      'gateway': 'razorpay',
      'mode': isTestMode ? 'test' : 'live',
      'platform': defaultTargetPlatform.name,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Best-effort ledger write for non-success outcomes; never throws.
  static Future<void> _recordAttempt(
      PremiumPlan plan, Map<String, Object?> fields) async {
    if (AuthService.currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(paymentsCollection)
          .add({...await _baseRecord(plan), ...fields});
    } catch (e) {
      debugPrint('[Payment] could not record payment attempt: $e');
    }
  }

  static Future<void> _handleSuccess(
    PremiumPlan plan,
    PaymentSuccessResponse r,
    void Function() onSuccess,
    void Function(String message) onError,
  ) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      onError('You must be signed in to upgrade.');
      _dispose();
      return;
    }

    // Renewing early stacks on top of the time already paid for.
    final now = DateTime.now();
    final current = SubscriptionService.premiumUntil;
    final start = (current != null && current.isAfter(now)) ? current : now;
    final until = DateTime(start.year, start.month + plan.months, start.day,
        start.hour, start.minute);

    final fs = FirebaseFirestore.instance;
    final payment = {
      ...await _baseRecord(plan),
      'status': 'success',
      'razorpayPaymentId': r.paymentId,
      'razorpayOrderId': r.orderId,
      'razorpaySignature': r.signature,
      'periodStart': Timestamp.fromDate(start),
      'periodEnd': Timestamp.fromDate(until),
      'verified': false, // set true by a server once signatures are checked
    };

    try {
      final subscription = <String, Object?>{
        'uid': uid,
        'isPremium': true,
        'plan': plan.id,
        'premiumUntil': Timestamp.fromDate(until),
        'currentPeriodStart': Timestamp.fromDate(start),
        if (SubscriptionService.premiumSince == null)
          'premiumSince': Timestamp.fromDate(now),
        'lastPaymentId': r.paymentId,
        'lastPaymentAt': FieldValue.serverTimestamp(),
        'lastAmountPaise': plan.pricePaise,
        'totalPaidPaise': FieldValue.increment(plan.pricePaise),
        'paymentsCount': FieldValue.increment(1),
        'mode': isTestMode ? 'test' : 'live',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final subRef = fs.collection('subscriptions').doc(uid);

      try {
        // Ledger entry + subscription update land together or not at all.
        final batch = fs.batch();
        batch.set(
          fs.collection(paymentsCollection)
              .doc(r.paymentId ?? fs.collection(paymentsCollection).doc().id),
          payment,
        );
        batch.set(subRef, subscription, SetOptions(merge: true));
        await batch.commit();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        // Ledger not writable (rules not deployed yet) — never let that
        // stop a paying customer getting Premium.
        debugPrint('[Payment] ledger write denied, activating without it');
        await subRef.set(subscription, SetOptions(merge: true));
      }

      await SubscriptionService.refresh();
      onSuccess();
    } catch (e) {
      debugPrint('[Payment] failed to record premium status: $e');
      // Money was taken but activation failed — make sure there's a trace.
      await _recordAttempt(plan, {
        ...payment,
        'status': 'activation_failed',
        'errorMessage': '$e',
      });
      onError('Payment succeeded, but we could not update your account. '
          'Please contact support with payment ID ${r.paymentId}.');
    } finally {
      _dispose();
    }
  }
  static void _dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}

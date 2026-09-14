import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'auth_service.dart';
import 'SubscriptionService.dart';

/// Razorpay checkout for the "Upgrade to Premium" flow.
///
/// DEMO MODE: [_keyId] below is a placeholder — it does not belong to any
/// real Razorpay account, so checkout will show Razorpay's "Invalid key"
/// error if actually launched with it. Replace it with a real key from
/// https://dashboard.razorpay.com/app/keys (use a `rzp_test_...` key while
/// developing, swap to `rzp_live_...` when you're ready to take real
/// payments) and everything else — checkout, success/failure handling,
/// marking the account premium — already works end to end.
///
/// This only handles the client-side checkout UI and marks the account
/// premium locally in Firestore on success. For real production billing
/// you'll also want a backend webhook (Razorpay calls your server on
/// payment events) that verifies the payment signature server-side before
/// trusting it — the client-side success callback alone is enough for a
/// demo/soft launch but is spoofable by a modified client.
class PaymentService {
  PaymentService._();

  /// TODO: replace with your real Razorpay key before going live.
  static const String _keyId = 'rzp_test_REPLACE_WITH_YOUR_KEY';

  static bool get isConfigured => !_keyId.contains('REPLACE_WITH');

  /// Premium plan price, in the smallest currency unit (paise for INR —
  /// i.e. ₹499.00 = 49900). Adjust to whatever you decide to charge.
  static const int premiumAmountPaise = 49900;
  static const String premiumAmountLabel = '₹499';

  static Razorpay? _razorpay;

  static void startCheckout({
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) {
    final user = AuthService.currentUser;

    final razorpay = Razorpay();
    _razorpay = razorpay;

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _handleSuccess(r, onSuccess, onError);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      onError(r.message ?? 'Payment failed. Please try again.');
      _dispose();
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // User picked a wallet app instead of completing in-checkout —
      // not a failure, just log it; Razorpay handles the redirect.
      debugPrint('[Payment] external wallet selected: ${r.walletName}');
    });

    razorpay.open({
      'key': _keyId,
      'amount': premiumAmountPaise,
      'currency': 'INR',
      'name': 'Fast Billing',
      'description': 'Premium plan — unlimited invoices',
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
      },
      'theme': {'color': '#4F46E5'},
    });
  }

  static Future<void> _handleSuccess(
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

    try {
      await FirebaseFirestore.instance.collection('subscriptions').doc(uid).set({
        'isPremium': true,
        'razorpayPaymentId': r.paymentId,
        'razorpayOrderId': r.orderId,
        'upgradedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await SubscriptionService.refresh();
      onSuccess();
    } catch (e) {
      debugPrint('[Payment] failed to record premium status: $e');
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

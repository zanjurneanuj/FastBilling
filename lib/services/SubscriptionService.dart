import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Soft paywall: the first [freeInvoiceLimit] invoices an account ever
/// creates are free. After that, [canCreateInvoice] goes false until
/// [isPremium] is set — e.g. manually by support today, or by a real
/// billing integration later. No payment processing happens here; this
/// only gates the "create invoice" entry points and reports usage.
///
/// Kept in its own Firestore collection (`subscriptions/{uid}`) rather
/// than on the business profile so a profile edit can never accidentally
/// overwrite the premium flag.
class SubscriptionService {
  SubscriptionService._();

  static const int freeInvoiceLimit = 10;
  static const _collection = 'subscriptions';

  static final ValueNotifier<int> changed = ValueNotifier(0);

  static int invoiceCount = 0;
  static bool isPremium = false;

  static int get remainingFree =>
      (freeInvoiceLimit - invoiceCount).clamp(0, freeInvoiceLimit);

  static bool get canCreateInvoice => isPremium || invoiceCount < freeInvoiceLimit;

  /// Call at startup, and again after a new invoice is saved, so the
  /// gate reflects reality without needing an app restart. Safe to call
  /// when signed out (no-op) and safe to call repeatedly.
  static Future<void> refresh() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      final agg = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .count()
          .get();
      invoiceCount = agg.count ?? 0;
    } catch (e) {
      debugPrint('[Subscription] invoice count refresh failed: $e');
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .get();
      isPremium = doc.data()?['isPremium'] == true;
    } catch (e) {
      debugPrint('[Subscription] premium status refresh failed: $e');
    }

    changed.value++;
  }
}

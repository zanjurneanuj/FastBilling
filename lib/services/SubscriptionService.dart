import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Free tier + Premium status. Every account gets [freeInvoiceLimit] free
/// invoices, plus [bonusPerReferral] more for each friend who joins with
/// their referral code. Premium (a prepaid plan, see PaymentService)
/// removes the limit and unlocks Pro / custom templates.
///
/// Kept in its own Firestore collection (`subscriptions/{uid}`) rather
/// than on the business profile so a profile edit can never accidentally
/// overwrite it. Premium is active while `premiumUntil` is in the future;
/// a doc with `isPremium: true` and no `premiumUntil` (granted manually by
/// support) never expires.
class SubscriptionService {
  SubscriptionService._();

  static const int freeInvoiceLimit = 10;
  static const int bonusPerReferral = 10;

  /// Saved clients / catalog items on the free plan. Existing ones are
  /// never removed (e.g. when Premium ends) — only adding more is blocked.
  static const int freeClientLimit = 10;
  static const int freeItemLimit = 10;
  static const _collection = 'subscriptions';

  static final ValueNotifier<int> changed = ValueNotifier(0);

  static int invoiceCount = 0;
  static bool _premiumFlag = false;
  static DateTime? premiumUntil;
  static DateTime? premiumSince;
  static String? planId;

  /// Friends who joined with this account's referral code.
  static int referralCount = 0;

  static int get bonusInvoices => referralCount * bonusPerReferral;

  /// Free invoices this account may create: base + referral bonus.
  static int get invoiceLimit => freeInvoiceLimit + bonusInvoices;

  static bool get isPremium {
    if (!_premiumFlag) return false;
    final until = premiumUntil;
    return until == null || until.isAfter(DateTime.now());
  }

  /// Premium that ran out — used to prompt a renewal.
  static bool get isExpired =>
      _premiumFlag && premiumUntil != null && !isPremium;

  /// Days of Premium left, or null when it doesn't expire / isn't active.
  static int? get daysLeft {
    final until = premiumUntil;
    if (!isPremium || until == null) return null;
    return until.difference(DateTime.now()).inDays;
  }

  static int get remainingFree =>
      (invoiceLimit - invoiceCount).clamp(0, invoiceLimit);

  static bool get canCreateInvoice => isPremium || invoiceCount < invoiceLimit;

  static bool canAddClient(int currentCount) =>
      isPremium || currentCount < freeClientLimit;

  static bool canAddItem(int currentCount) =>
      isPremium || currentCount < freeItemLimit;

  /// Forget everything about the previous account (on sign-out), so the
  /// next person to sign in on this device never inherits it.
  static void reset() {
    invoiceCount = 0;
    _premiumFlag = false;
    premiumUntil = null;
    premiumSince = null;
    planId = null;
    referralCount = 0;
    changed.value++;
  }

  /// Call after sign-in, and again after a new invoice is saved, so the
  /// gate reflects reality without needing an app restart. Safe to call
  /// when signed out (no-op) and safe to call repeatedly.
  static Future<void> refresh() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final fs = FirebaseFirestore.instance;
    // All reads in parallel — this runs right after sign-in.
    await Future.wait([
      () async {
        try {
          final agg = await fs
              .collection('users')
              .doc(uid)
              .collection('invoices')
              .count()
              .get();
          invoiceCount = agg.count ?? 0;
        } catch (e) {
          debugPrint('[Subscription] invoice count refresh failed: $e');
        }
      }(),
      () async {
        try {
          final data = (await fs.collection(_collection).doc(uid).get()).data();
          _premiumFlag = data?['isPremium'] == true;
          premiumUntil = (data?['premiumUntil'] as Timestamp?)?.toDate();
          premiumSince = (data?['premiumSince'] as Timestamp?)?.toDate();
          planId = data?['plan'] as String?;
        } catch (e) {
          debugPrint('[Subscription] premium status refresh failed: $e');
        }
      }(),
      () async {
        try {
          final agg = await fs
              .collection('referrals')
              .where('referrerUid', isEqualTo: uid)
              .count()
              .get();
          referralCount = agg.count ?? 0;
        } catch (e) {
          debugPrint('[Subscription] referral count refresh failed: $e');
        }
      }(),
    ]);

    // Ignore a result that arrived after the user switched accounts.
    if (AuthService.currentUser?.uid != uid) return;
    changed.value++;
  }
}

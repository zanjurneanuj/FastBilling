import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/InvoiceDetail.dart';
import '../models/PdfTemplate.dart';
import '../services/PdfTemplateService.dart';
import '../services/ProfileService.dart';
import '../services/SubscriptionService.dart';
import '../utils/invoice_events.dart';
import '../utils/invoice_status.dart';

class InvoicePreviewViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool notFound = false;
  String? errorMsg;
  InvoiceDetail? invoice;

  InvoicePreviewViewModel() {
    PdfTemplateService.changed.addListener(_onTemplateChanged);
    // Premium loading/expiring changes which template is effective.
    SubscriptionService.changed.addListener(_onTemplateChanged);
  }

  void _onTemplateChanged() {
    debugPrint('[PreviewVM] template changed → ${PdfTemplateService.selected.id}, notifying');
    notifyListeners();
  }

  @override
  void dispose() {
    PdfTemplateService.changed.removeListener(_onTemplateChanged);
    SubscriptionService.changed.removeListener(_onTemplateChanged);
    super.dispose();
  }

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _docRef(String invoiceId) {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('invoices')
        .doc(invoiceId);
  }

  Future<void> load(String invoiceId) async {
    isLoading = true;
    notFound = false;
    errorMsg = null;
    notifyListeners();

    final ref = _docRef(invoiceId);
    if (ref == null) {
      errorMsg = 'You must be signed in.';
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await ref.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final issuedAt = (data['invoiceDate'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate();

        final normalizedStatus = InvoiceStatus.normalize(
            data['status'] as String?, dueDate);

        invoice = InvoiceDetail.fromMap(
          {'id': invoiceId, ...data, 'status': normalizedStatus},
          profile: ProfileService.cached,
          issuedDate: DateFormat('d MMM yyyy')
              .format(issuedAt ?? dueDate ?? DateTime.now()),
          dueDate: dueDate,
        );
      } else {
        notFound = true;
      }
    } catch (e) {
      errorMsg = 'Could not load this invoice. Please try again.';
      debugPrint('[PreviewVM] load failed: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Exposes the currently active template so the view can read it.
  PdfTemplate get activeTemplate => PdfTemplateService.effective;

  Future<void> togglePaidStatus() async {
    final inv = invoice;
    if (inv == null) return;

    final wasPaid = inv.status.toLowerCase() == InvoiceStatus.paid;
    // What gets written to Firestore — only ever 'sent' or 'paid'.
    // 'overdue' is never stored; it's always derived from dueDate.
    final storedStatus = wasPaid ? InvoiceStatus.sent : InvoiceStatus.paid;
    final displayStatus =
        InvoiceStatus.normalize(storedStatus, inv.dueDate);

    // Optimistic update.
    invoice = inv.copyWith(status: displayStatus);
    notifyListeners();

    final ref = _docRef(inv.id);
    if (ref == null) return;
    try {
      await ref.update({
        'status': storedStatus,
        // Tracks real days-to-pay for the Reports screen; cleared if
        // un-marked so a later re-payment doesn't keep a stale date.
        'paidAt': storedStatus == InvoiceStatus.paid
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });
      InvoiceEvents.notify();
    } catch (e) {
      // Roll back on failure.
      invoice = inv;
      errorMsg = 'Could not update payment status. Please try again.';
      debugPrint('[PreviewVM] togglePaidStatus failed: $e');
      notifyListeners();
    }
  }

  Future<bool> deleteInvoice() async {
    final inv = invoice;
    if (inv == null) return false;

    final ref = _docRef(inv.id);
    if (ref == null) return false;

    try {
      await ref.delete();
      InvoiceEvents.notify();
      return true;
    } catch (e) {
      errorMsg = 'Could not delete this invoice. Please try again.';
      debugPrint('[PreviewVM] deleteInvoice failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Clones the current invoice into a new draft with a fresh invoice
  /// number, returning the new document's id, or null on failure.
  Future<String?> duplicateInvoice() async {
    final inv = invoice;
    final uid = _uid;
    if (inv == null || uid == null) return null;

    final newId = _generateInvoiceNumber();
    try {
      final newRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(newId);

      final now = DateTime.now();
      await newRef.set({
        'invoiceNumber': newId,
        'invoiceDate': Timestamp.fromDate(now),
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'poNumber': inv.poNumber ?? '',
        'clientId': inv.clientId,
        'clientName': inv.clientName,
        'clientEmail': inv.clientEmail,
        'clientPhone': inv.clientPhone ?? '',
        'clientAddress': inv.clientAddress ?? '',
        'clientGstin': inv.clientGstin ?? '',
        'clientState': inv.clientState ?? '',
        'items': inv.items.map((i) => i.toMap()).toList(),
        'gstPercent': inv.gstPercent,
        'discountAmt': inv.discountAmt,
        'otherCharges': inv.otherCharges,
        // A fresh copy hasn't been paid yet.
        'amountPaid': 0,
        'paymentMode': inv.paymentMode,
        'note': inv.note ?? '',
        'terms': inv.terms ?? '',
        'subtotal': inv.subtotal,
        'gstAmt': inv.gstAmt,
        'grandTotal': inv.grandTotal,
        'status': InvoiceStatus.draft,
        'createdAt': FieldValue.serverTimestamp(),
      });
      InvoiceEvents.notify();
      return newId;
    } catch (e) {
      errorMsg = 'Could not duplicate this invoice. Please try again.';
      debugPrint('[PreviewVM] duplicateInvoice failed: $e');
      notifyListeners();
      return null;
    }
  }

  static String _generateInvoiceNumber() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'INV-${now.year}-$seq';
  }
}

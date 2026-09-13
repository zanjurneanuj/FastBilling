import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/InvoiceDetail.dart';
import '../models/PdfTemplate.dart';
import '../services/PdfTemplateService.dart';
import '../services/ProfileService.dart';
import '../utils/invoice_status.dart';

class InvoicePreviewViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool notFound = false;
  String? errorMsg;
  InvoiceDetail? invoice;

  InvoicePreviewViewModel() {
    PdfTemplateService.changed.addListener(_onTemplateChanged);
  }

  void _onTemplateChanged() {
    debugPrint('[PreviewVM] template changed → ${PdfTemplateService.selected.id}, notifying');
    notifyListeners();
  }

  @override
  void dispose() {
    PdfTemplateService.changed.removeListener(_onTemplateChanged);
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
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final profile = ProfileService.cached;

        final normalizedStatus = InvoiceStatus.normalize(
            data['status'] as String?, dueDate);

        invoice = InvoiceDetail.fromMap(
          {'id': invoiceId, ...data, 'status': normalizedStatus},
          senderName: profile?.name ?? '',
          senderAddress: profile?.address ?? '',
          senderGst: profile?.gstNumber,
          issuedDate: DateFormat('d MMM yyyy')
              .format(createdAt ?? dueDate ?? DateTime.now()),
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
  PdfTemplate get activeTemplate => PdfTemplateService.selected;

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
      await ref.update({'status': storedStatus});
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

      await newRef.set({
        'invoiceNumber': newId,
        'dueDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
        'clientId': inv.clientId,
        'clientName': inv.clientName,
        'clientEmail': inv.clientEmail,
        'items': inv.items
            .map((i) => {'name': i.name, 'qty': i.qty, 'rate': i.rate, 'total': i.total})
            .toList(),
        'gstPercent': inv.gstPercent,
        'discountAmt': inv.discountAmt,
        'subtotal': inv.subtotal,
        'gstAmt': inv.gstAmt,
        'grandTotal': inv.grandTotal,
        'status': InvoiceStatus.draft,
        'createdAt': FieldValue.serverTimestamp(),
      });
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

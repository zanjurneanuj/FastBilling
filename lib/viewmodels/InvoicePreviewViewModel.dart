import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/InvoiceDetail.dart';
import '../models/InvoiceLineItem.dart';
import '../models/PdfTemplate.dart';
import '../services/PdfTemplateService.dart';



class InvoicePreviewViewModel extends ChangeNotifier {
  bool           isLoading = false;
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
  Future<void> load(String invoiceId) async {
    isLoading = true;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { isLoading = false; notifyListeners(); return; }

    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('invoices').doc(invoiceId)
        .get();

    if (doc.exists) {
      invoice = InvoiceDetail.fromMap(doc.data()!); // adjust to your model
    }

    isLoading = false;
    notifyListeners();
  }
  /// Exposes the currently active template so the view can read it.
  PdfTemplate get activeTemplate => PdfTemplateService.selected;

  void togglePaidStatus() {
    if (invoice == null) return;
    final next = invoice!.status.toLowerCase() == 'paid' ? 'Sent' : 'Paid';
    invoice = invoice!.copyWith(status: next);
    notifyListeners();
    // TODO: persist status change to DB
  }
}
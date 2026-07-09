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
  Future<void> load(String id) async {
    isLoading = true;
    notifyListeners();

    // ── Replace with real DB fetch by id ─────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 400));
    invoice = InvoiceDetail(
      invoiceNumber: 'INV-2026-014',
      status:        'Paid',
      senderName:    'Aarav Sharma',
      senderAddress: 'Bengaluru 560001',
      senderGst:     null, // null = unregistered
      clientName:    'Meridian Studio',
      clientEmail:   'hello@meridian.co',
      issuedDate:    '12 Jun 2026',
      gstPercent:    18,
      note: 'Thank you for your business. Payment received via UPI on 14 Jun 2026.',
      items: const [
        InvoiceLineItem(name: 'UI/UX Design',          qty: 24, rate: 2500),
        InvoiceLineItem(name: 'Logo & Identity',        qty: 1,  rate: 35000),
        InvoiceLineItem(name: 'Consultation',           qty: 3,  rate: 1500),
      ],
    );
    // ─────────────────────────────────────────────────────────────────────

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
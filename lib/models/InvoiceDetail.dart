import 'BusinessProfile.dart';
import 'InvoiceAttachment.dart';
import 'InvoiceLineItem.dart';
import '../utils/indian_states.dart';

/// One row of the GST summary table — all items sharing a tax rate.
class TaxSlab {
  final double rate;
  final double taxable;
  final double tax;
  const TaxSlab(this.rate, this.taxable, this.tax);
}

class InvoiceDetail {
  final String id; // Firestore doc id — same value as invoiceNumber
  final String invoiceNumber;
  final String status; // 'draft' | 'sent' | 'paid' | 'overdue'

  // ── Seller (from the business profile, not stored per invoice) ──────────
  final String senderName;
  final String senderAddress;
  final String? senderGst;
  final String? senderState;
  final String? senderPhone;
  final String? senderEmail;
  final String? senderPan;
  final String? senderUpiId;
  final String? senderSignatory;
  final String? senderLogoPath;
  final String? senderBankName;
  final String? senderBankAccountNo;
  final String? senderBankIfsc;

  // ── Buyer (snapshotted onto the invoice when it's saved) ────────────────
  final String? clientId;
  final String clientName;
  final String clientEmail;
  final String? clientPhone;
  final String? clientAddress;
  final String? clientGstin;
  final String? clientState;

  // ── Invoice meta ─────────────────────────────────────────────────────────
  final String issuedDate; // '12 Jun 2026'
  final DateTime? dueDate;
  final String? poNumber;
  final List<InvoiceLineItem> items;
  final double gstPercent; // default rate for items without their own
  final double discountAmt;
  final double otherCharges; // freight / packing etc., added before rounding
  final double amountPaid;
  final String? note;
  final String? terms;
  final String paymentMode;
  final List<InvoiceAttachment> attachments;

  /// Stamp "PAID" across the PDF when [status] is paid.
  final bool showPaidStamp;

  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.senderName,
    required this.senderAddress,
    this.senderGst,
    this.senderState,
    this.senderPhone,
    this.senderEmail,
    this.senderPan,
    this.senderUpiId,
    this.senderSignatory,
    this.senderLogoPath,
    this.senderBankName,
    this.senderBankAccountNo,
    this.senderBankIfsc,
    this.clientId,
    required this.clientName,
    required this.clientEmail,
    this.clientPhone,
    this.clientAddress,
    this.clientGstin,
    this.clientState,
    required this.issuedDate,
    this.dueDate,
    this.poNumber,
    required this.items,
    this.gstPercent = 18,
    this.discountAmt = 0,
    this.otherCharges = 0,
    this.amountPaid = 0,
    this.note,
    this.terms,
    this.paymentMode = 'Cash',
    this.attachments = const [],
    this.showPaidStamp = true,
  });

  /// Create InvoiceDetail from a raw Firestore invoice document map, with
  /// seller fields filled from the business [profile].
  factory InvoiceDetail.fromMap(
    Map<String, dynamic> map, {
    BusinessProfile? profile,
    String issuedDate = '',
    DateTime? dueDate,
  }) {
    String? s(String key) {
      final v = map[key] as String?;
      return (v == null || v.trim().isEmpty) ? null : v;
    }

    return InvoiceDetail(
      id: map['id'] ?? map['invoiceNumber'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      status: map['status'] ?? '',
      senderName: profile?.name ?? '',
      senderAddress: profile?.address ?? '',
      senderGst: profile?.gstNumber,
      senderState: profile?.state,
      senderPhone: profile?.phone,
      senderEmail: profile?.email,
      senderPan: profile?.pan,
      senderUpiId: profile?.upiId,
      senderSignatory: profile?.signatoryName,
      senderLogoPath: profile?.logoPath,
      senderBankName: profile?.bankName,
      senderBankAccountNo: profile?.bankAccountNo,
      senderBankIfsc: profile?.bankIfsc,
      clientId: map['clientId'],
      clientName: map['clientName'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      clientPhone: s('clientPhone'),
      clientAddress: s('clientAddress'),
      clientGstin: s('clientGstin'),
      clientState: s('clientState'),
      issuedDate: issuedDate,
      dueDate: dueDate,
      poNumber: s('poNumber'),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) =>
              InvoiceLineItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      gstPercent: (map['gstPercent'] ?? 18).toDouble(),
      discountAmt: (map['discountAmt'] ?? 0).toDouble(),
      otherCharges: (map['otherCharges'] ?? 0).toDouble(),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      note: s('note'),
      terms: s('terms'),
      paymentMode: map['paymentMode'] ?? 'Cash',
      attachments: (map['attachments'] as List<dynamic>? ?? [])
          .map((a) =>
              InvoiceAttachment.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      showPaidStamp: map['showPaidStamp'] != false,
    );
  }

  /// Taxable value of all items.
  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  /// Total GST across items, each at its own rate.
  double get gstAmt =>
      items.fold(0, (sum, item) => sum + item.taxAmount(gstPercent));

  /// Grand total before rounding.
  double get grandTotal => subtotal + gstAmt + otherCharges - discountAmt;

  /// Adjustment applied to reach [roundedTotal] — positive rounds up,
  /// negative rounds down, printed as its own line on the invoice.
  double get roundOff => roundedTotal - grandTotal;

  /// Grand total rounded to the nearest whole currency unit.
  double get roundedTotal => grandTotal.roundToDouble();

  double get balanceDue => isPaid ? 0 : roundedTotal - amountPaid;

  bool get isPaid => status.toLowerCase() == 'paid';

  /// Amount actually received — a paid invoice counts as fully received.
  double get received => isPaid ? roundedTotal : amountPaid;

  String? get sellerStateCode =>
      IndianStates.resolveCode(gstin: senderGst, state: senderState);
  String? get buyerStateCode =>
      IndianStates.resolveCode(gstin: clientGstin, state: clientState);

  /// Supply to another state is taxed as IGST; within the state it splits
  /// into CGST + SGST. Unknown buyer state is treated as intra-state.
  bool get isInterState {
    final a = sellerStateCode, b = buyerStateCode;
    return a != null && b != null && a != b;
  }

  /// "Place of supply" — the buyer's state, falling back to the seller's.
  String? get placeOfSupply =>
      IndianStates.label(gstin: clientGstin, state: clientState) ??
      IndianStates.label(gstin: senderGst, state: senderState);

  /// Items grouped by GST rate, for the tax summary table.
  List<TaxSlab> get taxSlabs {
    final taxable = <double, double>{};
    for (final i in items) {
      final r = i.taxRate(gstPercent);
      taxable[r] = (taxable[r] ?? 0) + i.total;
    }
    final rates = taxable.keys.toList()..sort();
    return [
      for (final r in rates) TaxSlab(r, taxable[r]!, taxable[r]! * r / 100),
    ];
  }

  /// Label for the single GST line in compact layouts, e.g. "GST 18%" or
  /// "GST" when items carry mixed rates.
  String get gstLabel {
    final rates = taxSlabs.map((s) => s.rate).where((r) => r > 0).toSet();
    return rates.length == 1 ? 'GST ${_pct(rates.first)}%' : 'GST';
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  InvoiceDetail copyWith({String? status}) => InvoiceDetail(
    id: id,
    invoiceNumber: invoiceNumber,
    status: status ?? this.status,
    senderName: senderName,
    senderAddress: senderAddress,
    senderGst: senderGst,
    senderState: senderState,
    senderPhone: senderPhone,
    senderEmail: senderEmail,
    senderPan: senderPan,
    senderUpiId: senderUpiId,
    senderSignatory: senderSignatory,
    senderLogoPath: senderLogoPath,
    senderBankName: senderBankName,
    senderBankAccountNo: senderBankAccountNo,
    senderBankIfsc: senderBankIfsc,
    clientId: clientId,
    clientName: clientName,
    clientEmail: clientEmail,
    clientPhone: clientPhone,
    clientAddress: clientAddress,
    clientGstin: clientGstin,
    clientState: clientState,
    issuedDate: issuedDate,
    dueDate: dueDate,
    poNumber: poNumber,
    items: items,
    gstPercent: gstPercent,
    discountAmt: discountAmt,
    otherCharges: otherCharges,
    amountPaid: amountPaid,
    note: note,
    terms: terms,
    paymentMode: paymentMode,
    attachments: attachments,
    showPaidStamp: showPaidStamp,
  );
}

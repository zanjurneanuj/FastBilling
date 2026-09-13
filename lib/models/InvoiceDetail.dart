import 'InvoiceLineItem.dart';

class InvoiceDetail {
  final String id; // Firestore doc id — same value as invoiceNumber
  final String invoiceNumber;
  final String status; // 'draft' | 'sent' | 'paid' | 'overdue'
  final String senderName;
  final String senderAddress;
  final String? senderGst;
  final String? clientId;
  final String clientName;
  final String clientEmail;
  final String issuedDate; // '12 Jun 2026'
  final DateTime? dueDate;
  final List<InvoiceLineItem> items;
  final double gstPercent;
  final double discountAmt;
  final String? note;

  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.senderName,
    required this.senderAddress,
    this.senderGst,
    this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.issuedDate,
    this.dueDate,
    required this.items,
    this.gstPercent = 18,
    this.discountAmt = 0,
    this.note,
  });

  /// Create InvoiceDetail from a raw Firestore invoice document map.
  /// Sender fields (name/address/gst) aren't stored per-invoice — pass
  /// them in explicitly (they come from the business profile) via the
  /// `senderName`/`senderAddress`/`senderGst` overrides.
  factory InvoiceDetail.fromMap(
    Map<String, dynamic> map, {
    String senderName = '',
    String senderAddress = '',
    String? senderGst,
    String issuedDate = '',
    DateTime? dueDate,
  }) {
    return InvoiceDetail(
      id: map['id'] ?? map['invoiceNumber'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      status: map['status'] ?? '',
      senderName: senderName,
      senderAddress: senderAddress,
      senderGst: senderGst,
      clientId: map['clientId'],
      clientName: map['clientName'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      issuedDate: issuedDate,
      dueDate: dueDate,
      items: (map['items'] as List<dynamic>? ?? [])
          .map(
            (item) => InvoiceLineItem.fromMap(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList(),
      gstPercent: (map['gstPercent'] ?? 18).toDouble(),
      discountAmt: (map['discountAmt'] ?? 0).toDouble(),
      note: map['note'],
    );
  }

  /// Calculate subtotal
  double get subtotal {
    return items.fold(0, (sum, item) => sum + item.total);
  }

  /// Calculate GST amount
  double get gstAmt {
    return subtotal * gstPercent / 100;
  }

  /// Calculate grand total
  double get grandTotal {
    return subtotal + gstAmt - discountAmt;
  }

  /// Create a copy with updated values
  InvoiceDetail copyWith({
    String? id,
    String? invoiceNumber,
    String? status,
    String? senderName,
    String? senderAddress,
    String? senderGst,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? issuedDate,
    DateTime? dueDate,
    List<InvoiceLineItem>? items,
    double? gstPercent,
    double? discountAmt,
    String? note,
  }) {
    return InvoiceDetail(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      senderGst: senderGst ?? this.senderGst,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      issuedDate: issuedDate ?? this.issuedDate,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      gstPercent: gstPercent ?? this.gstPercent,
      discountAmt: discountAmt ?? this.discountAmt,
      note: note ?? this.note,
    );
  }
}
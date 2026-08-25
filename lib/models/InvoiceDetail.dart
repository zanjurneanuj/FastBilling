import 'InvoiceLineItem.dart';

class InvoiceDetail {
  final String invoiceNumber;
  final String status; // 'Paid' | 'Sent' | 'Draft' | 'Overdue'
  final String senderName;
  final String senderAddress;
  final String? senderGst;
  final String clientName;
  final String clientEmail;
  final String issuedDate; // '12 Jun 2026'
  final List<InvoiceLineItem> items;
  final double gstPercent;
  final double discountAmt;
  final String? note;

  const InvoiceDetail({
    required this.invoiceNumber,
    required this.status,
    required this.senderName,
    required this.senderAddress,
    this.senderGst,
    required this.clientName,
    required this.clientEmail,
    required this.issuedDate,
    required this.items,
    this.gstPercent = 18,
    this.discountAmt = 0,
    this.note,
  });

  /// Create InvoiceDetail from Map
  factory InvoiceDetail.fromMap(Map<String, dynamic> map) {
    return InvoiceDetail(
      invoiceNumber: map['invoiceNumber'] ?? '',
      status: map['status'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAddress: map['senderAddress'] ?? '',
      senderGst: map['senderGst'],
      clientName: map['clientName'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      issuedDate: map['issuedDate'] ?? '',
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
    String? invoiceNumber,
    String? status,
    String? senderName,
    String? senderAddress,
    String? senderGst,
    String? clientName,
    String? clientEmail,
    String? issuedDate,
    List<InvoiceLineItem>? items,
    double? gstPercent,
    double? discountAmt,
    String? note,
  }) {
    return InvoiceDetail(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      senderGst: senderGst ?? this.senderGst,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      issuedDate: issuedDate ?? this.issuedDate,
      items: items ?? this.items,
      gstPercent: gstPercent ?? this.gstPercent,
      discountAmt: discountAmt ?? this.discountAmt,
      note: note ?? this.note,
    );
  }
}
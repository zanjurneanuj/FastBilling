
import 'InvoiceLineItem.dart';

class InvoiceDetail {
  final String   invoiceNumber;
  final String   status;         // 'Paid' | 'Sent' | 'Draft' | 'Overdue'
  final String   senderName;
  final String   senderAddress;
  final String?  senderGst;
  final String   clientName;
  final String   clientEmail;
  final String   issuedDate;     // '12 Jun 2026'
  final List<InvoiceLineItem> items;
  final double   gstPercent;
  final double   discountAmt;
  final String?  note;

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
    this.gstPercent  = 18,
    this.discountAmt = 0,
    this.note,
  });

  double get subtotal   => items.fold(0, (s, i) => s + i.total);
  double get gstAmt     => subtotal * gstPercent / 100;
  double get grandTotal => subtotal + gstAmt - discountAmt;

  InvoiceDetail copyWith({String? status}) => InvoiceDetail(
    invoiceNumber: invoiceNumber,
    status:        status ?? this.status,
    senderName:    senderName,
    senderAddress: senderAddress,
    senderGst:     senderGst,
    clientName:    clientName,
    clientEmail:   clientEmail,
    issuedDate:    issuedDate,
    items:         items,
    gstPercent:    gstPercent,
    discountAmt:   discountAmt,
    note:          note,
  );
}

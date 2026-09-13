/// Row shape for the Invoices list / client-detail invoice lists.
class InvoiceListItem {
  final String id;
  final String? clientId;
  final String clientName;
  final String invoiceNumber; // 'INV-2026-014'
  final String dateLabel; // '12 Jun'
  final double amount;
  final String status; // 'draft' | 'sent' | 'paid' | 'overdue'
  final DateTime? createdAt;

  const InvoiceListItem({
    required this.id,
    this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    required this.dateLabel,
    required this.amount,
    required this.status,
    this.createdAt,
  });
}

class InvoiceLineItem {
  final String name;
  final double qty;
  final double rate;
  double get total => qty * rate;
  const InvoiceLineItem({required this.name, required this.qty, required this.rate});
}
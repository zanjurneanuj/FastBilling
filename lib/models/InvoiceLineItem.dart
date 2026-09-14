class InvoiceLineItem {
  final String name;
  final double qty;
  final double rate;
  final String hsnCode;
  final String unit;

  double get total => qty * rate;

  const InvoiceLineItem({
    required this.name,
    required this.qty,
    required this.rate,
    this.hsnCode = '',
    this.unit = 'PCS',
  });

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) {
    return InvoiceLineItem(
      name: map['name'] ?? '',
      qty: (map['qty'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      hsnCode: map['hsnCode'] ?? '',
      unit: map['unit'] ?? 'PCS',
    );
  }
}

/// How an item's discount value is interpreted.
class DiscountType {
  DiscountType._();
  static const percent = 'percent';
  static const amount = 'amount';
}

class InvoiceLineItem {
  final String name;
  final double qty;
  final double rate;
  final String hsnCode;
  final String unit;

  /// Free-text detail printed under the item name — serial / IMEI numbers,
  /// model, size, etc.
  final String description;
  final String batchNo;
  final String expiry;

  /// Per-item GST rate. Null means "use the invoice's default GST %", which
  /// keeps invoices saved before per-item rates existed unchanged.
  final double? gstPercent;

  /// [DiscountType.percent] or [DiscountType.amount] (flat ₹ for the line).
  final String discountType;
  final double discountValue;

  /// True when [rate] already includes GST — the taxable value is then
  /// backed out of the price instead of tax being added on top.
  final bool taxInclusive;

  const InvoiceLineItem({
    required this.name,
    required this.qty,
    required this.rate,
    this.hsnCode = '',
    this.unit = 'PCS',
    this.description = '',
    this.batchNo = '',
    this.expiry = '',
    this.gstPercent,
    this.discountType = DiscountType.percent,
    this.discountValue = 0,
    this.taxInclusive = false,
  });

  /// qty × rate, before discount.
  double get gross => qty * rate;

  double get discountAmount {
    if (discountValue <= 0) return 0;
    final d = discountType == DiscountType.percent
        ? gross * discountValue / 100
        : discountValue;
    return d.clamp(0, gross).toDouble();
  }

  /// Taxable value (after discount, excluding GST). Inclusive pricing needs
  /// an explicit item rate to back the tax out; without one it's treated
  /// as exclusive.
  double get total {
    final net = gross - discountAmount;
    if (taxInclusive && gstPercent != null) return net / (1 + gstPercent! / 100);
    return net;
  }

  double taxRate(double invoiceDefault) => gstPercent ?? invoiceDefault;

  double taxAmount(double invoiceDefault) =>
      total * taxRate(invoiceDefault) / 100;

  /// What the customer pays for this line, GST included.
  double lineTotal(double invoiceDefault) =>
      total + taxAmount(invoiceDefault);

  factory InvoiceLineItem.fromMap(Map<String, dynamic> map) {
    return InvoiceLineItem(
      name: map['name'] ?? '',
      qty: (map['qty'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      hsnCode: map['hsnCode'] ?? '',
      unit: map['unit'] ?? 'PCS',
      description: map['description'] ?? '',
      batchNo: map['batchNo'] ?? '',
      expiry: map['expiry'] ?? '',
      gstPercent: (map['gstPercent'] as num?)?.toDouble(),
      discountType: map['discountType'] ?? DiscountType.percent,
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      taxInclusive: map['taxInclusive'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'rate': rate,
    'total': total,
    'hsnCode': hsnCode,
    'unit': unit,
    'description': description,
    'batchNo': batchNo,
    'expiry': expiry,
    if (gstPercent != null) 'gstPercent': gstPercent,
    'discountType': discountType,
    'discountValue': discountValue,
    'taxInclusive': taxInclusive,
  };

  InvoiceLineItem copyWith({
    String? name,
    double? qty,
    double? rate,
    String? hsnCode,
    String? unit,
    String? description,
    String? batchNo,
    String? expiry,
    double? gstPercent,
    String? discountType,
    double? discountValue,
    bool? taxInclusive,
  }) =>
      InvoiceLineItem(
        name: name ?? this.name,
        qty: qty ?? this.qty,
        rate: rate ?? this.rate,
        hsnCode: hsnCode ?? this.hsnCode,
        unit: unit ?? this.unit,
        description: description ?? this.description,
        batchNo: batchNo ?? this.batchNo,
        expiry: expiry ?? this.expiry,
        gstPercent: gstPercent ?? this.gstPercent,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
        taxInclusive: taxInclusive ?? this.taxInclusive,
      );
}

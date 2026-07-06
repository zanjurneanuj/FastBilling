import 'package:flutter/material.dart';

class LineItem {
  final String id;
  String name;
  double qty;
  double rate;

  LineItem({
    required this.id,
    this.name = '',
    this.qty  = 1,
    this.rate = 0,
  });

  double get total => qty * rate;

  LineItem copyWith({String? name, double? qty, double? rate}) => LineItem(
    id:   id,
    name: name  ?? this.name,
    qty:  qty   ?? this.qty,
    rate: rate  ?? this.rate,
  );
}

class InvoiceCreateViewModel extends ChangeNotifier {
  // ── Invoice meta ──────────────────────────────────────────────────────────
  String invoiceNumber = _generateInvoiceNumber();
  DateTime dueDate     = DateTime.now().add(const Duration(days: 30));

  // ── Client ────────────────────────────────────────────────────────────────
  String? clientId;
  String? clientName;
  String? clientEmail;

  // ── Line items ────────────────────────────────────────────────────────────
  List<LineItem> items = [];

  // ── Tax & discount ────────────────────────────────────────────────────────
  bool   taxExpanded   = false;
  double gstPercent    = 18.0;   // applied when > 0
  double discountAmt   = 0.0;    // flat discount

  // ── Status ────────────────────────────────────────────────────────────────
  bool   isSaving     = false;
  bool   isDraftSaved = false;
  String? errorMsg;

  // ── Computed ──────────────────────────────────────────────────────────────
  double get subtotal  => items.fold(0, (s, i) => s + i.total);
  double get gstAmt    => subtotal * gstPercent / 100;
  double get grandTotal => subtotal + gstAmt - discountAmt;

  // ── Line item CRUD ────────────────────────────────────────────────────────
  void addItem() {
    items = [
      ...items,
      LineItem(id: DateTime.now().millisecondsSinceEpoch.toString()),
    ];
    notifyListeners();
  }

  void updateItem(String id, {String? name, double? qty, double? rate}) {
    items = items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(name: name, qty: qty, rate: rate);
    }).toList();
    notifyListeners();
  }

  void removeItem(String id) {
    items = items.where((i) => i.id != id).toList();
    notifyListeners();
  }

  // ── Client ────────────────────────────────────────────────────────────────
  void setClient({
    required String id,
    required String name,
    required String email,
  }) {
    clientId    = id;
    clientName  = name;
    clientEmail = email;
    notifyListeners();
  }

  void clearClient() {
    clientId = clientName = clientEmail = null;
    notifyListeners();
  }

  // ── Tax / discount ────────────────────────────────────────────────────────
  void toggleTaxPanel() {
    taxExpanded = !taxExpanded;
    notifyListeners();
  }

  void setGst(double v) {
    gstPercent = v;
    notifyListeners();
  }

  void setDiscount(double v) {
    discountAmt = v;
    notifyListeners();
  }

  // ── Due date ──────────────────────────────────────────────────────────────
  void setDueDate(DateTime d) {
    dueDate = d;
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<bool> saveDraft() async {
    isSaving = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500)); // replace with DB call
    isSaving     = false;
    isDraftSaved = true;
    notifyListeners();
    return true;
  }

  Future<bool> saveAndSend() async {
    if (clientId == null) {
      errorMsg = 'Please select a client.';
      notifyListeners();
      return false;
    }
    if (items.isEmpty) {
      errorMsg = 'Add at least one line item.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    errorMsg = null;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600)); // replace with DB + send call
    isSaving = false;
    notifyListeners();
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _generateInvoiceNumber() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    return 'INV-${now.year}-$seq';
  }

  String fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String fmtFull(double v) {
    // e.g. 117410 → "1,17,410"  (Indian numbering)
    final s = v.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3  = s.substring(s.length - 3);
    final rest   = s.substring(0, s.length - 3);
    final groups = <String>[];
    var r = rest;
    while (r.length > 2) {
      groups.insert(0, r.substring(r.length - 2));
      r = r.substring(0, r.length - 2);
    }
    if (r.isNotEmpty) groups.insert(0, r);
    return '${groups.join(',')},${last3}';
  }
}
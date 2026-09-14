import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LineItem {
  final String id;
  String name;
  double qty;
  double rate;
  String hsnCode;
  String unit;

  LineItem({
    required this.id,
    this.name = '',
    this.qty  = 1,
    this.rate = 0,
    this.hsnCode = '',
    this.unit = 'PCS',
  });

  double get total => qty * rate;

  LineItem copyWith({
    String? name,
    double? qty,
    double? rate,
    String? hsnCode,
    String? unit,
  }) => LineItem(
    id:      id,
    name:    name    ?? this.name,
    qty:     qty     ?? this.qty,
    rate:    rate    ?? this.rate,
    hsnCode: hsnCode ?? this.hsnCode,
    unit:    unit    ?? this.unit,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'qty': qty,
    'rate': rate,
    'total': total,
    'hsnCode': hsnCode,
    'unit': unit,
  };
}

class InvoiceCreateViewModel extends ChangeNotifier {
  InvoiceCreateViewModel({String? editInvoiceId}) {
    if (editInvoiceId != null) {
      isEditing = true;
      invoiceNumber = editInvoiceId;
      _loadForEdit(editInvoiceId);
    }
  }

  final _firestore = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Invoice meta ──────────────────────────────────────────────────────────
  String invoiceNumber = _generateInvoiceNumber();
  DateTime dueDate     = DateTime.now().add(const Duration(days: 30));

  // ── Editing an existing invoice instead of creating a new one ─────────────
  bool isEditing        = false;
  bool isLoadingExisting = false;

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

  // ── Payment ───────────────────────────────────────────────────────────────
  static const paymentModes = ['Cash', 'Bank transfer', 'UPI', 'Cheque', 'Card'];
  String paymentMode = 'Cash';

  // ── Status ────────────────────────────────────────────────────────────────
  bool   isSaving     = false;
  bool   isDraftSaved = false;
  String? errorMsg;

  Future<void> _loadForEdit(String id) async {
    final uid = _uid;
    if (uid == null) return;

    isLoadingExisting = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(id)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        invoiceNumber = (data['invoiceNumber'] as String?) ?? id;
        clientId = data['clientId'] as String?;
        clientName = data['clientName'] as String?;
        clientEmail = data['clientEmail'] as String?;

        final due = (data['dueDate'] as Timestamp?)?.toDate();
        if (due != null) dueDate = due;

        gstPercent = (data['gstPercent'] as num?)?.toDouble() ?? gstPercent;
        discountAmt = (data['discountAmt'] as num?)?.toDouble() ?? discountAmt;
        paymentMode = data['paymentMode'] as String? ?? paymentMode;

        final rawItems = data['items'] as List<dynamic>? ?? [];
        items = rawItems.asMap().entries.map((entry) {
          final m = Map<String, dynamic>.from(entry.value as Map);
          return LineItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
            name: m['name'] as String? ?? '',
            qty: (m['qty'] as num?)?.toDouble() ?? 1,
            rate: (m['rate'] as num?)?.toDouble() ?? 0,
            hsnCode: m['hsnCode'] as String? ?? '',
            unit: m['unit'] as String? ?? 'PCS',
          );
        }).toList();
      } else {
        errorMsg = 'Could not find this invoice.';
      }
    } catch (e) {
      debugPrint('Error loading invoice for edit: $e');
      errorMsg = 'Could not load invoice for editing.';
    }

    isLoadingExisting = false;
    notifyListeners();
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  double get subtotal  => items.fold(0, (s, i) => s + i.total);
  double get gstAmt    => subtotal * gstPercent / 100;
  double get grandTotal => subtotal + gstAmt - discountAmt;
  double get roundOff => roundedTotal - grandTotal;
  double get roundedTotal => grandTotal.roundToDouble();

  // ── Line item CRUD ────────────────────────────────────────────────────────
  void addItem() {
    items = [
      ...items,
      LineItem(id: DateTime.now().millisecondsSinceEpoch.toString()),
    ];
    notifyListeners();
  }

  void updateItem(
    String id, {
    String? name,
    double? qty,
    double? rate,
    String? hsnCode,
    String? unit,
  }) {
    items = items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(
        name: name,
        qty: qty,
        rate: rate,
        hsnCode: hsnCode,
        unit: unit,
      );
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

  void setPaymentMode(String v) {
    paymentMode = v;
    notifyListeners();
  }

  // ── Due date ──────────────────────────────────────────────────────────────
  void setDueDate(DateTime d) {
    dueDate = d;
    notifyListeners();
  }

  // ── Firestore helpers ────────────────────────────────────────────────────
  Map<String, dynamic> _toMap({required String status}) => {
    'invoiceNumber': invoiceNumber,
    'dueDate': Timestamp.fromDate(dueDate),
    'clientId': clientId,
    'clientName': clientName,
    'clientEmail': clientEmail,
    'items': items.map((i) => i.toMap()).toList(),
    'gstPercent': gstPercent,
    'discountAmt': discountAmt,
    'paymentMode': paymentMode,
    'subtotal': subtotal,
    'gstAmt': gstAmt,
    'grandTotal': grandTotal,
    'status': status, // 'draft' | 'sent'
    // Only stamp createdAt for brand-new invoices — editing an existing one
    // must not bump it, since it drives "recent invoices" / monthly-revenue
    // ordering everywhere else in the app.
    if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
  };

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<bool> saveDraft() async {
    final uid = _uid;

    if (uid == null) {
      errorMsg = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMsg = null;
    notifyListeners();

    try {
      final invoiceRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoiceNumber);

      final data = _toMap(status: 'draft');

      await invoiceRef.set(
        data,
        SetOptions(merge: true),
      );

      isSaving = false;
      isDraftSaved = true;
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('[InvoiceCreate] saveDraft failed: $e\n$stackTrace');

      isSaving = false;
      errorMsg = 'Failed to save invoice: $e';
      notifyListeners();

      return false;
    }
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

    final uid = _uid;
    if (uid == null) {
      errorMsg = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMsg = null;
    notifyListeners();

    try {
      final invoiceRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoiceNumber);

      await invoiceRef.set(_toMap(status: 'sent'));

      // Keep the client's totalBilled in sync
      final clientRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('clients')
          .doc(clientId);
      await clientRef.update({
        'totalBilled': FieldValue.increment(grandTotal),
      });

      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      isSaving = false;
      errorMsg = 'Failed to save invoice. Please try again.';
      notifyListeners();
      return false;
    }
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
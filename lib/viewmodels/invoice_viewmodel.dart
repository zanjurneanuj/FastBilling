import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ClientItem.dart';
import '../models/InvoiceAttachment.dart';
import '../models/InvoiceDetail.dart';
import '../models/InvoiceLineItem.dart';
import '../services/ProfileService.dart';
import '../services/SubscriptionService.dart';
import '../utils/invoice_events.dart';
import '../utils/invoice_status.dart';
import '../services/local_db_service.dart';

/// An invoice line plus a stable id for list keys / editing.
class LineItem {
  final String id;
  final InvoiceLineItem data;

  const LineItem({required this.id, required this.data});

  double get total => data.total;
}

class InvoiceCreateViewModel extends ChangeNotifier {
  InvoiceCreateViewModel({String? editInvoiceId}) {
    if (editInvoiceId != null) {
      isEditing = true;
      invoiceNumber = editInvoiceId;
      _loadForEdit(editInvoiceId);
    } else {
      _prefillTerms();
    }
  }

  static const _termsSettingKey = 'last_invoice_terms';

  final _firestore = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Invoice meta ──────────────────────────────────────────────────────────
  String invoiceNumber = _generateInvoiceNumber();
  DateTime invoiceDate = DateTime.now();
  DateTime dueDate     = DateTime.now().add(const Duration(days: 30));
  String poNumber      = '';

  // ── Editing an existing invoice instead of creating a new one ─────────────
  bool isEditing        = false;
  bool isLoadingExisting = false;

  // ── Client (snapshotted onto the invoice) ─────────────────────────────────
  String? clientId;
  String? clientName;
  String? clientEmail;
  String clientPhone   = '';
  String clientAddress = '';
  String clientGstin   = '';
  String clientState   = '';

  // ── Line items ────────────────────────────────────────────────────────────
  List<LineItem> items = [];

  // ── Tax & discount ────────────────────────────────────────────────────────
  bool   taxExpanded   = false;
  double gstPercent    = 18.0;   // default for items without their own rate
  double discountAmt   = 0.0;    // flat discount
  double otherCharges  = 0.0;    // freight / packing
  double amountPaid    = 0.0;

  // ── Notes ─────────────────────────────────────────────────────────────────
  bool   moreExpanded = false;
  String note  = '';
  String terms = '';

  // ── Paid status & attachments ─────────────────────────────────────────────
  bool isPaid = false;
  bool showPaidStamp = true;
  List<InvoiceAttachment> attachments = [];

  // ── Payment ───────────────────────────────────────────────────────────────
  static const paymentModes = ['Cash', 'Bank transfer', 'UPI', 'Cheque', 'Card', 'Credit'];
  String paymentMode = 'Cash';

  // ── Status ────────────────────────────────────────────────────────────────
  bool   isSaving     = false;
  bool   isDraftSaved = false;
  String? errorMsg;

  Future<void> _prefillTerms() async {
    try {
      final saved = await LocalDbService.instance.getSetting(_termsSettingKey);
      if (saved != null && terms.isEmpty) {
        terms = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InvoiceCreate] terms prefill failed: $e');
    }
  }

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
        final d = InvoiceDetail.fromMap({'id': id, ...data});
        invoiceNumber = d.invoiceNumber.isEmpty ? id : d.invoiceNumber;
        clientId = d.clientId;
        clientName = data['clientName'] as String?;
        clientEmail = data['clientEmail'] as String?;
        clientPhone = d.clientPhone ?? '';
        clientAddress = d.clientAddress ?? '';
        clientGstin = d.clientGstin ?? '';
        clientState = d.clientState ?? '';

        final due = (data['dueDate'] as Timestamp?)?.toDate();
        if (due != null) dueDate = due;
        final issued = (data['invoiceDate'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate();
        if (issued != null) invoiceDate = issued;
        poNumber = d.poNumber ?? '';

        gstPercent = d.gstPercent;
        discountAmt = d.discountAmt;
        otherCharges = d.otherCharges;
        amountPaid = d.amountPaid;
        paymentMode = d.paymentMode;
        note = d.note ?? '';
        terms = d.terms ?? '';
        moreExpanded = poNumber.isNotEmpty;
        isPaid = (data['status'] as String?)?.toLowerCase() == InvoiceStatus.paid;
        showPaidStamp = d.showPaidStamp;
        attachments = d.attachments;
        taxExpanded = otherCharges > 0 || amountPaid > 0;

        final stamp = DateTime.now().millisecondsSinceEpoch;
        items = [
          for (var i = 0; i < d.items.length; i++)
            LineItem(id: '${stamp}_$i', data: d.items[i]),
        ];
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

  // ── Computed (all math lives in InvoiceDetail) ────────────────────────────
  // Built once per change and reused by every getter / widget in a frame;
  // any notifyListeners() invalidates it.
  InvoiceDetail? _detail;

  @override
  void notifyListeners() {
    _detail = null;
    super.notifyListeners();
  }

  InvoiceDetail toDetail() => _detail ??= _buildDetail();

  InvoiceDetail _buildDetail() => InvoiceDetail(
    id: invoiceNumber,
    invoiceNumber: invoiceNumber,
    status: isPaid ? InvoiceStatus.paid : InvoiceStatus.draft,
    senderName: ProfileService.cached?.name ?? '',
    senderAddress: ProfileService.cached?.address ?? '',
    senderGst: ProfileService.cached?.gstNumber,
    senderState: ProfileService.cached?.state,
    clientId: clientId,
    clientName: clientName ?? '',
    clientEmail: clientEmail ?? '',
    clientGstin: clientGstin,
    clientState: clientState,
    issuedDate: DateFormat('d MMM yyyy').format(invoiceDate),
    dueDate: dueDate,
    items: items.map((i) => i.data).toList(),
    gstPercent: gstPercent,
    discountAmt: discountAmt,
    otherCharges: otherCharges,
    amountPaid: amountPaid,
    paymentMode: paymentMode,
    attachments: attachments,
    showPaidStamp: showPaidStamp,
  );

  double get subtotal     => toDetail().subtotal;
  double get gstAmt       => toDetail().gstAmt;
  double get grandTotal   => toDetail().grandTotal;
  double get roundOff     => toDetail().roundOff;
  double get roundedTotal => toDetail().roundedTotal;
  double get balanceDue   => toDetail().balanceDue;
  bool   get isInterState => toDetail().isInterState;
  String get gstLabel     => toDetail().gstLabel;

  // ── Line item CRUD ────────────────────────────────────────────────────────
  void addItem(InvoiceLineItem item) {
    items = [
      ...items,
      LineItem(id: DateTime.now().microsecondsSinceEpoch.toString(), data: item),
    ];
    notifyListeners();
  }

  void replaceItem(String id, InvoiceLineItem item) {
    items = [
      for (final i in items) i.id == id ? LineItem(id: id, data: item) : i,
    ];
    notifyListeners();
  }

  void removeItem(String id) {
    items = items.where((i) => i.id != id).toList();
    notifyListeners();
  }

  // ── Client ────────────────────────────────────────────────────────────────
  void setClient(ClientItem c) {
    clientId      = c.id;
    clientName    = c.name;
    clientEmail   = c.email;
    clientPhone   = c.phone;
    clientAddress = c.fullAddress;
    clientGstin   = c.gstin;
    clientState   = c.state;
    notifyListeners();
  }

  void clearClient() {
    clientId = clientName = clientEmail = null;
    clientPhone = clientAddress = clientGstin = clientState = '';
    notifyListeners();
  }

  // ── Tax / discount / charges ──────────────────────────────────────────────
  void toggleTaxPanel() {
    taxExpanded = !taxExpanded;
    notifyListeners();
  }

  void toggleMorePanel() {
    moreExpanded = !moreExpanded;
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

  void setOtherCharges(double v) {
    otherCharges = v;
    notifyListeners();
  }

  void setAmountPaid(double v) {
    amountPaid = v;
    notifyListeners();
  }

  void setPaid(bool v) {
    isPaid = v;
    notifyListeners();
  }

  void setShowPaidStamp(bool v) {
    showPaidStamp = v;
    notifyListeners();
  }

  /// Copies a picked image into app storage (the picker's cache can be
  /// cleared at any time) and adds it; uploaded when the invoice is saved.
  Future<void> addAttachment(String pickedPath, String name) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/att_${DateTime.now().microsecondsSinceEpoch}_$name';
      await File(pickedPath).copy(dest);
      attachments = [...attachments, InvoiceAttachment(name: name, path: dest)];
    } catch (e) {
      debugPrint('[InvoiceCreate] attachment copy failed: $e');
      attachments = [...attachments, InvoiceAttachment(name: name, path: pickedPath)];
    }
    notifyListeners();
  }

  void removeAttachment(int index) {
    attachments = [...attachments]..removeAt(index);
    notifyListeners();
  }

  /// Uploads attachments that only exist on this device. A failed upload
  /// keeps the local copy, so the invoice still saves.
  Future<void> _uploadAttachments(String uid) async {
    final out = <InvoiceAttachment>[];
    for (final a in attachments) {
      if (a.url != null || a.path == null || !File(a.path!).existsSync()) {
        out.add(a);
        continue;
      }
      try {
        final ref = FirebaseStorage.instance.ref(
            'invoice_attachments/$uid/$invoiceNumber/${DateTime.now().millisecondsSinceEpoch}_${a.name}');
        await ref.putFile(File(a.path!), SettableMetadata(contentType: _imageType(a.name)));
        out.add(a.withUrl(await ref.getDownloadURL()));
      } catch (e) {
        debugPrint('[InvoiceCreate] attachment upload failed, kept local: $e');
        out.add(a);
      }
    }
    attachments = out;
  }

  static String _imageType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  void setPaymentMode(String v) {
    paymentMode = v;
    notifyListeners();
  }

  // Text fields below don't need a rebuild on every keystroke.
  void setPoNumber(String v) => poNumber = v;
  void setNote(String v) => note = v;
  void setTerms(String v) => terms = v;

  void appendTerms(String line) {
    terms = terms.trim().isEmpty ? line : '${terms.trimRight()}\n$line';
    notifyListeners();
  }

  // ── Dates ─────────────────────────────────────────────────────────────────
  void setInvoiceDate(DateTime d) {
    invoiceDate = d;
    if (dueDate.isBefore(d)) dueDate = d;
    notifyListeners();
  }

  void setDueDate(DateTime d) {
    dueDate = d;
    notifyListeners();
  }

  // ── Firestore helpers ────────────────────────────────────────────────────
  /// [merge] is true for draft saves (set with merge), where a stale
  /// paidAt must be deleted explicitly; full overwrites just omit it.
  Map<String, dynamic> _toMap({required String status, bool merge = false}) {
    final d = _buildDetail(); // fresh — some text fields don't notify
    final paid = isPaid;
    return {
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'poNumber': poNumber.trim(),
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'clientGstin': clientGstin,
      'clientState': clientState,
      'items': d.items.map((i) => i.toMap()).toList(),
      'gstPercent': gstPercent,
      'discountAmt': discountAmt,
      'otherCharges': otherCharges,
      // Marked paid means fully received.
      'amountPaid': paid ? d.roundedTotal : amountPaid,
      'paymentMode': paymentMode,
      'showPaidStamp': showPaidStamp,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      if (paid)
        'paidAt': FieldValue.serverTimestamp()
      else if (merge)
        'paidAt': FieldValue.delete(),
      'note': note.trim(),
      'terms': terms.trim(),
      'subtotal': d.subtotal,
      'gstAmt': d.gstAmt,
      'grandTotal': d.grandTotal,
      'status': paid ? InvoiceStatus.paid : status, // 'draft' | 'sent' | 'paid'
      // Only stamp createdAt for brand-new invoices — editing an existing one
      // must not bump it, since it drives "recent invoices" / monthly-revenue
      // ordering everywhere else in the app.
      if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _rememberTerms() async {
    try {
      await LocalDbService.instance
          .saveSetting(_termsSettingKey, terms.trim());
    } catch (e) {
      debugPrint('[InvoiceCreate] saving terms failed: $e');
    }
  }

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
      await _uploadAttachments(uid);
      final invoiceRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoiceNumber);

      await invoiceRef.set(
        _toMap(status: 'draft', merge: true),
        SetOptions(merge: true),
      );
      unawaited(_rememberTerms());

      isSaving = false;
      isDraftSaved = true;
      notifyListeners();
      InvoiceEvents.notify();
      if (!isEditing) unawaited(SubscriptionService.refresh());

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
      await _uploadAttachments(uid);
      final invoiceRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .doc(invoiceNumber);

      await invoiceRef.set(_toMap(status: 'sent'));
      unawaited(_rememberTerms());

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
      InvoiceEvents.notify();
      if (!isEditing) unawaited(SubscriptionService.refresh());
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

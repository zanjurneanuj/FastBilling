import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/InvoiceLineItem.dart';

// ── Data model ────────────────────────────────────────────────────────────
// A saved item: everything needed to drop it onto an invoice again —
// price, unit, tax, default discount and details — plus stock.

class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String unit;
  final String hsnCode;
  final double? gstPercent;
  final bool taxInclusive;
  final String discountType;
  final double discountValue;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.unit = 'PCS',
    this.hsnCode = '',
    this.gstPercent,
    this.taxInclusive = false,
    this.discountType = DiscountType.percent,
    this.discountValue = 0,
    this.description = '',
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'PCS',
      hsnCode: map['hsnCode'] as String? ?? '',
      gstPercent: (map['gstPercent'] as num?)?.toDouble(),
      taxInclusive: map['taxInclusive'] == true,
      discountType: map['discountType'] as String? ?? DiscountType.percent,
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String? ?? '',
    );
  }

  /// Saved-item template from an invoice line. Per-sale details (qty,
  /// batch, expiry) stay on the invoice; [stock] is carried over.
  factory Product.fromLineItem(String id, InvoiceLineItem i, {int stock = 0}) =>
      Product(
        id: id,
        name: i.name.trim(),
        price: i.rate,
        stock: stock,
        unit: i.unit,
        hsnCode: i.hsnCode,
        gstPercent: i.gstPercent,
        taxInclusive: i.taxInclusive,
        discountType: i.discountType,
        discountValue: i.discountValue,
        description: i.description,
      );

  InvoiceLineItem toLineItem({double qty = 1}) => InvoiceLineItem(
    name: name,
    qty: qty,
    rate: price,
    unit: unit,
    hsnCode: hsnCode,
    gstPercent: gstPercent,
    taxInclusive: taxInclusive,
    discountType: discountType,
    discountValue: discountValue,
    description: description,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'nameLower': name.toLowerCase(),
    'price': price,
    'stock': stock,
    'unit': unit,
    'hsnCode': hsnCode,
    'gstPercent': gstPercent,
    'taxInclusive': taxInclusive,
    'discountType': discountType,
    'discountValue': discountValue,
    'description': description,
  };

  Product copyWith({String? id, String? name, double? price, int? stock}) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      unit: unit,
      hsnCode: hsnCode,
      gstPercent: gstPercent,
      taxInclusive: taxInclusive,
      discountType: discountType,
      discountValue: discountValue,
      description: description,
    );
  }
}

// ── View model ────────────────────────────────────────────────────────────
// Catalog items persist to users/{uid}/catalog, same shape as
// ClientsViewModel — optimistic local updates, rolled back on failure.

class CatalogViewModel extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  final List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _products.isEmpty;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Screens may close while a save is still in flight; late updates are
  // then dropped instead of notifying a disposed notifier.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> get _catalogRef {
    final uid = _uid;
    if (uid == null) throw Exception('No signed-in user.');
    return _firestore.collection('users').doc(uid).collection('catalog');
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final uid = _uid;
    if (uid == null) {
      _products.clear();
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final snapshot =
      await _catalogRef.orderBy('name').get();
      _products
        ..clear()
        ..addAll(snapshot.docs.map((d) => Product.fromMap(d.id, d.data())));
    } catch (e) {
      _error = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    await saveProduct(product.copyWith(id: ''));
  }

  /// Creates the product (empty [Product.id]) or overwrites the existing
  /// one. Returns the saved product, or null if the write failed.
  Future<Product?> saveProduct(Product product) async {
    final isNew = product.id.isEmpty;
    final docRef = isNew ? _catalogRef.doc() : _catalogRef.doc(product.id);
    final saved = product.copyWith(id: docRef.id);

    final index = _products.indexWhere((p) => p.id == saved.id);
    final previous = index == -1 ? null : _products[index];
    if (index == -1) {
      _products.add(saved);
    } else {
      _products[index] = saved;
    }
    _products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _error = null;
    notifyListeners();

    try {
      await docRef.set(saved.toMap());
      return saved;
    } catch (e) {
      _error = 'Could not save this item. Please try again.';
      if (previous == null) {
        _products.removeWhere((p) => p.id == saved.id);
      } else {
        _products[_products.indexWhere((p) => p.id == saved.id)] = previous;
      }
      notifyListeners();
      return null;
    }
  }

  /// Finds a saved item by name (case-insensitive) — used to update rather
  /// than duplicate when the same item is saved from an invoice again.
  Product? findByName(String name) {
    final n = name.trim().toLowerCase();
    for (final p in _products) {
      if (p.name.toLowerCase() == n) return p;
    }
    return null;
  }

  Future<void> updateStock(String id, int newStock) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final previous = _products[index];

    _products[index] = previous.copyWith(stock: newStock);
    _error = null;
    notifyListeners();

    try {
      await _catalogRef.doc(id).update({'stock': newStock});
    } catch (e) {
      _error = 'Could not update stock. Please try again.';
      _products[index] = previous;
      notifyListeners();
    }
  }

  Future<void> removeProduct(String id) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final removed = _products.removeAt(index);
    _error = null;
    notifyListeners();

    try {
      await _catalogRef.doc(id).delete();
    } catch (e) {
      _error = 'Could not delete this product. Please try again.';
      _products.insert(index, removed);
      notifyListeners();
    }
  }
}

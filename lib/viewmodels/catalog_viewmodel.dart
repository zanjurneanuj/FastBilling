import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ── Data model ────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String name;
  final double price;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'stock': stock,
  };

  Product copyWith({String? name, double? price, int? stock}) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
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
    final docRef = _catalogRef.doc();
    final saved = Product(
      id: docRef.id,
      name: product.name,
      price: product.price,
      stock: product.stock,
    );

    _products.add(saved); // optimistic UI
    _error = null;
    notifyListeners();

    try {
      await docRef.set(saved.toMap());
    } catch (e) {
      _error = 'Could not save this product. Please try again.';
      _products.removeWhere((p) => p.id == saved.id);
      notifyListeners();
    }
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

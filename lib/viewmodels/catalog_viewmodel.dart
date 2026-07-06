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

  factory Product.empty() => Product(id: '', name: '', price: 0, stock: 0);

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: json['stock'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
    };
  }

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
// Catalog owns its product list. Local/optimistic updates via notifyListeners;
// persistence (API / local DB) is left as TODOs, same as SettingsViewModel.

class CatalogViewModel extends ChangeNotifier {
  final List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _products.isEmpty;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: replace with real data source (API / local DB)
      await Future.delayed(const Duration(milliseconds: 300));
      _products
        ..clear()
        ..addAll(<Product>[]); // TODO: populate from persistence
    } catch (e) {
      _error = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
    // TODO: persist to local storage / backend
  }

  void updateStock(String id, int newStock) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(stock: newStock);
    notifyListeners();
    // TODO: persist to local storage / backend
  }

  void removeProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
    // TODO: persist to local storage / backend
  }
}
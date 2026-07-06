import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/catalog_viewmodel.dart';


class CatalogView extends StatelessWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CatalogViewModel>(
      create: (_) => CatalogViewModel()..loadProducts(),
      child: const _CatalogBody(),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog'),
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductSheet(context, vm),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CatalogViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vm.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: vm.loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (vm.isEmpty) {
      return const Center(child: Text('No products yet. Tap + to add one.'));
    }

    return ListView.separated(
      itemCount: vm.products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = vm.products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text('₹${product.price.toStringAsFixed(2)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stock: ${product.stock}'),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => vm.removeProduct(product.id),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddProductSheet(BuildContext context, CatalogViewModel vm) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  vm.addProduct(
                    Product(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name,
                      price: double.tryParse(priceController.text) ?? 0,
                      stock: int.tryParse(stockController.text) ?? 0,
                    ),
                  );
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Add product'),
              ),
            ],
          ),
        );
      },
    );
  }
}
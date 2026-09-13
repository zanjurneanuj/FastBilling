import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../viewmodels/catalog_viewmodel.dart';
import '../widgets/empty_state.dart';

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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        title: Text('Catalog',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductSheet(context, vm),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CatalogViewModel vm) {
    if (vm.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vm.error!,
                style: TextStyle(color: AppColors.textSecondary(context))),
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
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        subtitle: 'Tap + Add item to build your catalog.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: vm.products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _ProductRow(product: vm.products[index], vm: vm),
      ),
    );
  }

  void _showAddProductSheet(BuildContext context, CatalogViewModel vm) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 32,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border(sheetContext),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text('New Product',
                    style: TextStyle(
                        color: AppColors.textPrimary(sheetContext),
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Product name *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price *'),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Price is required';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      vm.addProduct(
                        Product(
                          id: '',
                          name: nameController.text.trim(),
                          price: double.parse(priceController.text.trim()),
                          stock: int.tryParse(stockController.text.trim()) ?? 0,
                        ),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Add product'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.vm});
  final Product product;
  final CatalogViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text('₹${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12)),
              ]),
        ),
        Text('Stock: ${product.stock}',
            style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
          onPressed: () => vm.removeProduct(product.id),
        ),
      ]),
    );
  }
}

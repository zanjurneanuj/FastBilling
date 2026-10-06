import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../utils/plan_limits.dart';
import '../../viewmodels/catalog_viewmodel.dart';
import '../widgets/empty_state.dart';
import 'item_edit_view.dart';

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary(context)),
          onPressed: () =>
          context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text('Catalog',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await ensureCanAddItem(context, vm.products.length) &&
              context.mounted) {
            openSavedItemEditor(context, catalog: vm);
          }
        },
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
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.vm});
  final Product product;
  final CatalogViewModel vm;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openSavedItemEditor(context, product: product, catalog: vm),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                Text([
                  '₹${product.price.toStringAsFixed(2)} / ${product.unit}',
                  if (product.gstPercent != null)
                    'GST ${product.gstPercent!.toStringAsFixed(0)}%${product.taxInclusive ? ' incl.' : ''}',
                  if (product.hsnCode.isNotEmpty) 'HSN ${product.hsnCode}',
                ].join(' · '),
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
      ),
    );
  }
}

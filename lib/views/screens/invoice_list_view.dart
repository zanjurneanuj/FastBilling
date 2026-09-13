import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/InvoiceListItem.dart';
import '../../utils/app_colors.dart';
import '../../utils/invoice_status.dart';
import '../../viewmodels/invoice_list_viewmodel.dart';
import '../widgets/client_avatar.dart';
import '../widgets/empty_state.dart';

/// Public entry point for the /invoices route.
///
/// This wraps the actual screen in its own ChangeNotifierProvider so the
/// route works standalone — it no longer depends on some ancestor route
/// (e.g. one declared only in main.dart, or a sibling route) having
/// already provided InvoiceListViewModel. That mismatch is what caused:
///   "Could not find the correct Provider<InvoiceListViewModel> above
///    this Consumer<InvoiceListViewModel> Widget"
/// go_router builds each route as its own subtree, so a provider placed
/// above the router (or in a different branch) does not automatically
/// reach every route — each route that needs the VM must be scoped to
/// provide it itself, or it must be provided above the router in a way
/// that wraps *all* routes (e.g. via ShellRoute). Self-providing here is
/// the safest fix regardless of how the router is structured elsewhere.
class InvoiceListView extends StatelessWidget {
  const InvoiceListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InvoiceListViewModel(),
      child: const _InvoiceListScreen(),
    );
  }
}

class _InvoiceListScreen extends StatefulWidget {
  const _InvoiceListScreen();

  @override
  State<_InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<_InvoiceListScreen> {
  final _searchCtrl = TextEditingController();

  static const _filters = ['All', 'Draft', 'Sent', 'Paid', 'Overdue'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceListViewModel>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceListViewModel>(
      builder: (context, vm, _) {
        final filtered = vm.filteredInvoices;

        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    children: [
                      Text('Invoices',
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.tune_rounded,
                            color: AppColors.textSecondary(context)),
                        onPressed: () => _showFilterSheet(context, vm),
                      ),
                    ],
                  ),
                ),

                // ── Search bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: vm.setSearchQuery,
                    style: TextStyle(
                        color: AppColors.textPrimary(context), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search invoice or client',
                      hintStyle: TextStyle(
                          color: AppColors.textHint(context), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textHint(context), size: 20),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // ── Filter chips ────────────────────────────────────────
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final selected = vm.selectedFilter == f;
                      return GestureDetector(
                        onTap: () => vm.setFilter(f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surface(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border(context),
                            ),
                          ),
                          child: Text(f,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary(context))),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Invoice list ────────────────────────────────────────
                Expanded(
                  child: vm.isLoading
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                      : filtered.isEmpty
                      ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: vm.selectedFilter == 'All'
                        ? 'No invoices yet'
                        : 'No ${vm.selectedFilter} invoices',
                    subtitle: 'Tap + New to create one.',
                  )
                      : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: vm.loadInvoices,
                    child: ListView.separated(
                      padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) => _InvoiceRow(
                        invoice: filtered[i],
                        onTap: () => context.push(
                            '/invoices/${filtered[i].id}/preview'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── FAB ─────────────────────────────────────────────────────────
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/invoices/create'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, InvoiceListViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border(context),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Sort & Filter',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                const SizedBox(height: 16),
                Text('Sort by',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  _SheetChip(
                    label: 'Newest first',
                    selected: vm.sort == InvoiceSort.newest,
                    onTap: () => setSheetState(
                        () => vm.setSort(InvoiceSort.newest)),
                  ),
                  _SheetChip(
                    label: 'Oldest first',
                    selected: vm.sort == InvoiceSort.oldest,
                    onTap: () => setSheetState(
                        () => vm.setSort(InvoiceSort.oldest)),
                  ),
                  _SheetChip(
                    label: 'Amount ↑',
                    selected: vm.sort == InvoiceSort.amountAsc,
                    onTap: () => setSheetState(
                        () => vm.setSort(InvoiceSort.amountAsc)),
                  ),
                  _SheetChip(
                    label: 'Amount ↓',
                    selected: vm.sort == InvoiceSort.amountDesc,
                    onTap: () => setSheetState(
                        () => vm.setSort(InvoiceSort.amountDesc)),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Apply'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}

// ─── Invoice Row ────────────────────────────────────────────────────────────

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onTap});
  final InvoiceListItem invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(children: [
          // Avatar
          ClientAvatar(name: invoice.clientName),
          const SizedBox(width: 12),

          // Name + invoice number
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.clientName,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    '${invoice.invoiceNumber} · ${invoice.dateLabel}',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                ]),
          ),

          // Amount + status badge
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${_fmt(invoice.amount)}',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _StatusBadge(status: invoice.status),
          ]),
        ]),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─── Status Badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = InvoiceStatus.badgeColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(InvoiceStatus.label(status),
          style:
          TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Sheet Chip ──────────────────────────────────────────────────────────────

class _SheetChip extends StatelessWidget {
  const _SheetChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border(context),
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary(context))),
    ),
  );
}
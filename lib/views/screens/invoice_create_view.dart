import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/InvoiceLineItem.dart';
import '../../utils/app_colors.dart';
import '../../utils/plan_limits.dart';
import '../../viewmodels/client_viewmodel.dart';
import '../../viewmodels/invoice_viewmodel.dart';
import '../widgets/client_tax_fields.dart';
import 'item_edit_view.dart';

class InvoiceCreateView extends StatelessWidget {
  const InvoiceCreateView({super.key, this.editInvoiceId});
  final String? editInvoiceId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InvoiceCreateViewModel(editInvoiceId: editInvoiceId),
      child: const _InvoiceCreateBody(),
    );
  }
}

class _InvoiceCreateBody extends StatelessWidget {
  const _InvoiceCreateBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceCreateViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: AppColors.background(context),
          // ── AppBar ──────────────────────────────────────────────────────
          appBar: AppBar(
            backgroundColor: AppColors.surface(context),
            elevation: 1,
            scrolledUnderElevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textPrimary(context),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            title: Text(
              vm.isEditing ? 'Edit Invoice' : 'New Invoice',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (vm.isDraftSaved)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Draft saved',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          body: vm.isLoadingExisting
              ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
            children: [
              // ── Scrollable form ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Invoice no. + Due date ─────────────────────────
                      _MetaRow(vm: vm),
                      const SizedBox(height: 16),

                      // ── Client picker ──────────────────────────────────
                      _ClientPicker(vm: vm),
                      const SizedBox(height: 20),

                      // ── Line items ─────────────────────────────────────
                      _SectionLabel('LINE ITEMS'),
                      const SizedBox(height: 10),
                      for (final (n, item) in vm.items.indexed)
                        _LineItemCard(
                          key: ValueKey(item.id),
                          index: n + 1,
                          item: item.data,
                          defaultGst: vm.gstPercent,
                          onTap: () async {
                            final r = await openItemEditor(context,
                                initial: item.data, defaultGst: vm.gstPercent);
                            if (r == null) return;
                            if (r.deleted) {
                              vm.removeItem(item.id);
                            } else {
                              vm.replaceItem(item.id, r.item!);
                            }
                          },
                          onDelete: () => vm.removeItem(item.id),
                        ),

                      // ── Add item button ────────────────────────────────
                      _AddItemButton(onTap: () async {
                        final r = await openItemEditor(context,
                            defaultGst: vm.gstPercent);
                        if (r?.item != null) vm.addItem(r!.item!);
                      }),
                      const SizedBox(height: 14),

                      // ── Tax & charges ──────────────────────────────────
                      _TaxDiscountPanel(vm: vm),
                      const SizedBox(height: 12),

                      // ── PO / reference ─────────────────────────────────
                      _MoreDetailsPanel(vm: vm),
                      const SizedBox(height: 20),

                      // ── Totals ─────────────────────────────────────────
                      _TotalsSection(vm: vm),
                      const SizedBox(height: 22),

                      // ── Payment: paid / unpaid, mode, stamp ────────────
                      _SectionLabel('PAYMENT'),
                      const SizedBox(height: 10),
                      _PaymentCard(vm: vm),
                      const SizedBox(height: 22),

                      // ── Terms & notes ──────────────────────────────────
                      _SectionLabel('TERMS & NOTES'),
                      const SizedBox(height: 10),
                      _TermsNotesCard(vm: vm),
                      const SizedBox(height: 22),

                      // ── Attachments ────────────────────────────────────
                      _SectionLabel('ATTACHMENTS'),
                      const SizedBox(height: 10),
                      _AttachmentsCard(vm: vm),

                      // Error banner
                      if (vm.errorMsg != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(vm.errorMsg!),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Bottom action bar ────────────────────────────────────────
              _BottomBar(vm: vm),
            ],
          ),
        );
      },
    );
  }
}

// ─── Meta Row (invoice no + due date) ────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.vm});

  final InvoiceCreateViewModel vm;

  Future<DateTime?> _pick(
      BuildContext context, DateTime initial, DateTime first) {
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      // Colours come from the app theme's datePickerTheme, which has
      // light and dark variants (a forced light scheme here made the dates
      // white-on-white in dark mode).
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yy');
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _MetaTile(
            label: 'Invoice no.',
            value: vm.invoiceNumber,
            onTap: null, // read-only
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _MetaTile(
            label: 'Date',
            value: fmt.format(vm.invoiceDate),
            onTap: () async {
              final picked = await _pick(context, vm.invoiceDate,
                  DateTime.now().subtract(const Duration(days: 365)));
              if (picked != null) vm.setInvoiceDate(picked);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _MetaTile(
            label: 'Due date',
            value: fmt.format(vm.dueDate),
            onTap: () async {
              final picked = await _pick(context, vm.dueDate, vm.invoiceDate);
              if (picked != null) vm.setDueDate(picked);
            },
          ),
        ),
      ],
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Client Picker ────────────────────────────────────────────────────────────

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    final hasClient = vm.clientName != null;

    return GestureDetector(
      onTap: () => _showClientSheet(context, vm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasClient
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (hasClient) ...[
              _Avatar(name: vm.clientName!),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.clientName!,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (vm.clientEmail != null)
                      Text(
                        vm.clientEmail!,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    if (vm.clientGstin.isNotEmpty || vm.clientState.isNotEmpty)
                      Text(
                        [
                          if (vm.clientGstin.isNotEmpty) 'GSTIN ${vm.clientGstin}',
                          if (vm.clientState.isNotEmpty) vm.clientState,
                          vm.isInterState ? 'IGST' : 'CGST + SGST',
                        ].join(' · '),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
            ] else ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_add_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Select client',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context),
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showClientSheet(BuildContext context, InvoiceCreateViewModel vm) {
    final clientsVm = context.read<ClientsViewModel>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => StatefulBuilder(
          builder: (context, setSheetState) {
            final clients = clientsVm.clients;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Select Client',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      'Add new client',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      if (!await ensureCanAddClient(
                              context, clientsVm.clients.length) ||
                          !context.mounted) {
                        return;
                      }
                      _showAddClientSheet(
                        context,
                        vm,
                        clientsVm,
                        onAdded: () => setSheetState(() {}),
                      );
                    },
                  ),
                  Divider(color: AppColors.border(context), height: 1),
                  const SizedBox(height: 4),
                  Expanded(
                    child: clients.isEmpty
                        ? Center(
                            child: Text(
                              'No clients yet — add one above.',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: ctrl,
                            itemCount: clients.length,
                            separatorBuilder: (_, __) => Divider(
                              color: AppColors.border(context),
                              height: 1,
                            ),
                            itemBuilder: (_, i) {
                              final c = clients[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _Avatar(name: c.name),
                                title: Text(
                                  c.name,
                                  style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  c.email,
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  vm.setClient(c);
                                  Navigator.pop(sheetContext);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Inline "add client" form layered on top of the client picker — saves
  /// via the same ClientsViewModel the standalone Clients screen uses, then
  /// immediately selects the new client for this invoice.
  void _showAddClientSheet(
    BuildContext context,
    InvoiceCreateViewModel vm,
    ClientsViewModel clientsVm, {
    required VoidCallback onAdded,
  }) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    String? state;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
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
                Text('New Client',
                    style: TextStyle(
                        color: AppColors.textPrimary(sheetContext),
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business name *'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone · optional'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City · optional'),
                ),
                const SizedBox(height: 14),
                ClientTaxFields(
                  addressCtrl: addressCtrl,
                  gstinCtrl: gstinCtrl,
                  state: state,
                  onStateChanged: (v) => setModalState(() => state = v),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => saving = true);
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      await clientsVm.addClient(
                        name: name,
                        email: email,
                        phone: phoneCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        gstin: gstinCtrl.text.trim().toUpperCase(),
                        state: state ?? '',
                      );

                      if (clientsVm.errorMsg != null) {
                        setModalState(() => saving = false);
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(clientsVm.errorMsg!)));
                        }
                        return;
                      }

                      final newClient = clientsVm.clients
                          .firstWhere((c) => c.name == name && c.email == email);
                      vm.setClient(newClient);
                      onAdded();
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext); // close add-client sheet
                      }
                      if (context.mounted) {
                        Navigator.pop(context); // close client picker sheet
                      }
                    },
                    child: saving
                        ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                        : const Text('Save & select'),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Line Item Card ───────────────────────────────────────────────────────────
// Read-only summary of one line; tapping opens the full item screen.

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.defaultGst,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final InvoiceLineItem item;
  final double defaultGst;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static final _grouped = NumberFormat('#,##,##0.##', 'en_IN');
  static String _n(double v) => _grouped.format(v);

  @override
  Widget build(BuildContext context) {
    final rate = item.taxRate(defaultGst);
    final chips = <String>[
      if (item.hsnCode.isNotEmpty) 'HSN ${item.hsnCode}',
      'GST ${_n(rate)}%${item.taxInclusive ? ' incl.' : ''}',
      if (item.discountAmount > 0)
        item.discountType == DiscountType.percent
            ? '${_n(item.discountValue)}% off'
            : '₹${_n(item.discountValue)} off',
      if (item.batchNo.isNotEmpty) 'Batch ${item.batchNo}',
      if (item.expiry.isNotEmpty) 'Exp ${item.expiry}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$index',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textPrimary(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text('₹${_n(item.lineTotal(defaultGst))}',
                              style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_n(item.qty)} ${item.unit} × ₹${_n(item.rate)}',
                        style: TextStyle(
                            color: AppColors.textSecondary(context), fontSize: 12),
                      ),
                      if (item.description.isNotEmpty)
                        Text(item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textHint(context), fontSize: 11)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final c in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background(context),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(c,
                                  style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary(context)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Selectable chip (GST rates, payment modes) ───────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.background(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border(context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.textSecondary(context),
        ),
      ),
    ),
  );
}

// ─── Add item button ──────────────────────────────────────────────────────────

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          const Text(
            'Add item',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

/// ─── Collapsible card shared by the tax and "more details" panels ────────────

class _ExpandableCard extends StatelessWidget {
  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.summary,
  });

  final IconData icon;
  final String title;
  final String? summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary(context), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (summary != null && !expanded)
                    Expanded(
                      child: Text(
                        summary!,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: AppColors.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small right-aligned ₹ input used for discount / charges / amount paid.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  static String _trim(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: value == 0 ? '' : _trim(value),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            decoration: _boxedDecoration(context, hint: '0', prefix: '₹ '),
          ),
        ),
      ],
    );
  }
}

InputDecoration _boxedDecoration(BuildContext context,
    {String? hint, String? prefix, String? label}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixText: prefix,
    hintStyle: TextStyle(color: AppColors.textHint(context)),
    filled: true,
    fillColor: AppColors.background(context),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: border(AppColors.border(context)),
    enabledBorder: border(AppColors.border(context)),
    focusedBorder: border(AppColors.primary, 1.5),
  );
}

// ─── Tax & Charges Panel ──────────────────────────────────────────────────────

class _TaxDiscountPanel extends StatelessWidget {
  const _TaxDiscountPanel({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(color: AppColors.textSecondary(context), fontSize: 13);
    return _ExpandableCard(
      icon: Icons.percent_rounded,
      title: 'Tax & charges',
      summary: [
        'GST ${vm.gstPercent.toStringAsFixed(0)}%',
        if (vm.discountAmt > 0) 'Disc ₹${vm.fmt(vm.discountAmt)}',
        if (vm.otherCharges > 0) '+₹${vm.fmt(vm.otherCharges)}',
      ].join(' · '),
      expanded: vm.taxExpanded,
      onToggle: vm.toggleTaxPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default GST % for new items', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final pct in const [0.0, 5.0, 12.0, 18.0, 28.0])
                _Chip(
                  label: pct == 0 ? 'None' : '${pct.toStringAsFixed(0)}%',
                  selected: vm.gstPercent == pct,
                  onTap: () => vm.setGst(pct),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _AmountField(
            label: 'Bill discount (flat)',
            value: vm.discountAmt,
            onChanged: vm.setDiscount,
          ),
          const SizedBox(height: 10),
          _AmountField(
            label: 'Other charges (freight, packing)',
            value: vm.otherCharges,
            onChanged: vm.setOtherCharges,
          ),
        ],
      ),
    );
  }
}

// ─── PO / reference number ────────────────────────────────────────────────────

class _MoreDetailsPanel extends StatelessWidget {
  const _MoreDetailsPanel({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return _ExpandableCard(
      icon: Icons.tag_rounded,
      title: 'PO / reference no.',
      summary: vm.poNumber.isEmpty ? 'Optional' : vm.poNumber,
      expanded: vm.moreExpanded,
      onToggle: vm.toggleMorePanel,
      child: TextFormField(
        initialValue: vm.poNumber,
        onChanged: vm.setPoNumber,
        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
        decoration: _boxedDecoration(context, label: 'PO / reference no.'),
      ),
    );
  }
}

// ─── Plain card wrapper for the always-open sections ─────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

// ─── Payment: paid / unpaid, mode, amount received, stamp ────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.vm});
  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(color: AppColors.textSecondary(context), fontSize: 13);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Unpaid'),
                  icon: Icon(Icons.schedule_rounded, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Paid'),
                  icon: Icon(Icons.check_circle_rounded, size: 16),
                ),
              ],
              selected: {vm.isPaid},
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected)
                        ? (vm.isPaid ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.15)
                        : null),
                foregroundColor: WidgetStateProperty.resolveWith((s) =>
                    s.contains(WidgetState.selected)
                        ? (vm.isPaid ? AppColors.paidText : AppColors.pendingText)
                        : AppColors.textSecondary(context)),
              ),
              onSelectionChanged: (s) => vm.setPaid(s.first),
            ),
          ),
          const SizedBox(height: 16),
          Text(vm.isPaid ? 'Received via' : 'Payment mode', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mode in InvoiceCreateViewModel.paymentModes)
                _Chip(
                  label: mode,
                  selected: vm.paymentMode == mode,
                  onTap: () => vm.setPaymentMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!vm.isPaid)
            _AmountField(
              label: 'Advance / part payment received',
              value: vm.amountPaid,
              onChanged: vm.setAmountPaid,
            )
          else
            Row(
              children: [
                // Mini preview of the stamp printed on the PDF.
                Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: vm.showPaidStamp
                              ? AppColors.paidText
                              : AppColors.border(context),
                          width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('PAID',
                        style: TextStyle(
                            color: vm.showPaidStamp
                                ? AppColors.paidText
                                : AppColors.textHint(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PAID stamp on PDF',
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text('Balance due becomes ₹0',
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: vm.showPaidStamp,
                  activeThumbColor: AppColors.success,
                  onChanged: vm.setShowPaidStamp,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Terms & notes ────────────────────────────────────────────────────────────

class _TermsNotesCard extends StatelessWidget {
  const _TermsNotesCard({required this.vm});
  final InvoiceCreateViewModel vm;

  static const _presets = [
    'Payment due within 15 days.',
    'Goods once sold will not be taken back.',
    'Subject to local jurisdiction.',
    'Interest @18% p.a. on overdue payments.',
  ];

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(color: AppColors.textPrimary(context), fontSize: 14);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: vm.note,
            onChanged: vm.setNote,
            maxLines: 3,
            minLines: 2,
            style: textStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: _boxedDecoration(context,
                label: 'Notes for customer', hint: 'Thank you for your business!'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            // Re-seed when a preset is appended below.
            key: ValueKey('terms-${vm.terms.hashCode}'),
            initialValue: vm.terms,
            onChanged: vm.setTerms,
            maxLines: 5,
            minLines: 3,
            style: textStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: _boxedDecoration(context,
                label: 'Terms & conditions',
                hint: 'Goods once sold will not be taken back.'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _presets)
                if (!vm.terms.contains(p))
                  ActionChip(
                    label: Text('+ $p', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => vm.appendTerms(p),
                  ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Terms are remembered for your next invoice.',
              style: TextStyle(color: AppColors.textHint(context), fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Attachments ──────────────────────────────────────────────────────────────

class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({required this.vm});
  final InvoiceCreateViewModel vm;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final files = source == ImageSource.gallery
          ? await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80)
          : [
              if (await picker.pickImage(
                      source: source, maxWidth: 1600, imageQuality: 80)
                  case final f?)
                f,
            ];
      for (final f in files) {
        await vm.addAttachment(f.path, f.name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add attachment: $e')));
      }
    }
  }

  void _chooseSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheet);
                _pick(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheet);
                _pick(context, ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos of challans, receipts or delivered goods — added as pages at the end of the PDF.',
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, a) in vm.attachments.indexed)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: a.path != null && File(a.path!).existsSync()
                            ? Image.file(File(a.path!), fit: BoxFit.cover)
                            : a.url != null
                                ? Image.network(a.url!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image_outlined))
                                : const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => vm.removeAttachment(i),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                    if (a.url != null)
                      const Positioned(
                        left: 4,
                        bottom: 4,
                        child: Icon(Icons.cloud_done_rounded,
                            size: 14, color: Colors.white),
                      ),
                  ],
                ),
              InkWell(
                onTap: () => _chooseSource(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.primary),
                      SizedBox(height: 2),
                      Text('Add',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Totals ───────────────────────────────────────────────────────────────────

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    final d = vm.toDetail();
    final muted =
        TextStyle(color: AppColors.textSecondary(context), fontSize: 13);
    String money(double v) => '₹${vm.fmtFull(v)}';
    Widget row(String l, String v, {TextStyle? valueStyle}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _TotalRow(
              label: l, value: v, labelStyle: muted, valueStyle: valueStyle ?? muted),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                row('Taxable value', money(d.subtotal)),
                if (d.gstAmt > 0) ...[
                  if (d.isInterState)
                    row('IGST', money(d.gstAmt))
                  else ...[
                    row('CGST', money(d.gstAmt / 2)),
                    row('SGST', money(d.gstAmt / 2)),
                  ],
                ],
                if (d.otherCharges > 0)
                  row('Other charges', '+${money(d.otherCharges)}'),
                if (d.discountAmt > 0)
                  row('Discount', '−${money(d.discountAmt)}',
                      valueStyle:
                          const TextStyle(color: AppColors.success, fontSize: 13)),
                if (d.roundOff.abs() >= 0.005)
                  row('Rounded off',
                      '${d.roundOff > 0 ? '+' : '−'}₹${d.roundOff.abs().toStringAsFixed(2)}'),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      money(d.roundedTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                if (d.isPaid) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paid in full · ${vm.paymentMode}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const Text('Balance due ₹0',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ] else if (d.amountPaid > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Received ${money(d.amountPaid)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Balance due ${money(d.balanceDue)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: labelStyle),
      Text(value, style: valueStyle),
    ],
  );
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(
        children: [
          // Preview
          Expanded(
            child: OutlinedButton(
              onPressed: vm.isSaving
                  ? null
                  : () async {
                final ok = await vm.saveDraft();
                if (ok && context.mounted) {
                        context.push('/invoices/${vm.invoiceNumber}/preview');
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Save & send
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await vm.saveAndSend();
                if (ok && context.mounted) {
                  context.push('/invoices/${vm.invoiceNumber}/preview');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save & send',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  static const _palettes = [
    (bg: Color(0xFFE8E4FF), fg: Color(0xFF6C5CE7)),
    (bg: Color(0xFFE0F4FF), fg: Color(0xFF0984E3)),
    (bg: Color(0xFFFFE8E8), fg: Color(0xFFE17055)),
    (bg: Color(0xFFE8FFE8), fg: Color(0xFF00B894)),
    (bg: Color(0xFFFFF3E0), fg: Color(0xFFF39C12)),
  ];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % _palettes.length;
    final c = _palettes[idx];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: c.fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

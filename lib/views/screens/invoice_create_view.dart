import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../viewmodels/client_viewmodel.dart';
import '../../viewmodels/invoice_viewmodel.dart';

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
            elevation: 0,
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
                      ...vm.items.map(
                        (item) => _LineItemRow(
                          key: ValueKey(item.id),
                          item: item,
                          onChanged: ({name, qty, rate, hsnCode, unit}) =>
                              vm.updateItem(
                            item.id,
                            name: name,
                            qty: qty,
                            rate: rate,
                            hsnCode: hsnCode,
                            unit: unit,
                          ),
                          onDelete: () => vm.removeItem(item.id),
                        ),
                      ),

                      // ── Add item button ────────────────────────────────
                      _AddItemButton(onTap: vm.addItem),
                      const SizedBox(height: 14),

                      // ── Tax & discount ─────────────────────────────────
                      _TaxDiscountPanel(vm: vm),
                      const SizedBox(height: 20),

                      // ── Totals ─────────────────────────────────────────
                      _TotalsSection(vm: vm),

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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetaTile(
            label: 'Invoice no.',
            value: vm.invoiceNumber,
            onTap: null, // read-only
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetaTile(
            label: 'Due date',
            value: DateFormat('d MMM yyyy').format(vm.dueDate),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: vm.dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.primary,
                      onSurface: AppColors.textPrimary(ctx),
                    ),
                  ),
                  child: child!,
                ),
              );
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
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
                  ],
                ),
              ),
              Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
            ] else ...[
              Icon(
                Icons.person_add_outlined,
                color: AppColors.textSecondary(context),
                size: 20,
              ),
              const SizedBox(width: 10),
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
                    onTap: () => _showAddClientSheet(
                      context,
                      vm,
                      clientsVm,
                      onAdded: () => setSheetState(() {}),
                    ),
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
                                  vm.setClient(
                                    id: c.id,
                                    name: c.name,
                                    email: c.email,
                                  );
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
                      vm.setClient(
                        id: newClient.id,
                        name: newClient.name,
                        email: newClient.email,
                      );
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
    );
  }
}

// ─── Line Item Row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final LineItem item;
  final void Function({
    String? name,
    double? qty,
    double? rate,
    String? hsnCode,
    String? unit,
  }) onChanged;
  final VoidCallback onDelete;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _hsnCtrl;
  late final TextEditingController _unitCtrl;
  bool _nameFocused = false;
  bool _detailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.item.name.isEmpty ? '' : widget.item.name,
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.qty == 1 ? '1' : widget.item.qty.toStringAsFixed(0),
    );
    _rateCtrl = TextEditingController(
      text: widget.item.rate == 0 ? '' : _trimTrailingZero(widget.item.rate),
    );
    _hsnCtrl = TextEditingController(text: widget.item.hsnCode);
    _unitCtrl = TextEditingController(text: widget.item.unit);
    _detailsExpanded = widget.item.hsnCode.isNotEmpty;
  }

  static String _trimTrailingZero(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _hsnCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  // ── Shared input decoration (no underline, no outline) ──────────────────
  InputDecoration _collapsed(String hint, BuildContext context) =>
      InputDecoration.collapsed(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textHint(context),
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = widget.item.total;
    final hasValue = total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _nameFocused
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border(context),
          width: _nameFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top section: icon + name + total + delete ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),

                // Name field — Expanded directly in Row (no wrapper)
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) =>
                        setState(() => _nameFocused = focused),
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (v) => widget.onChanged(name: v),
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      decoration: _collapsed('Item name', context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Total
                Text(
                  '₹${_fmtNum(total)}',
                  style: TextStyle(
                    color: hasValue
                        ? AppColors.textPrimary(context)
                        : AppColors.textHint(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),

                // Delete button
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────
          Divider(height: 1, color: AppColors.border(context)),

          // ── Bottom section: qty × rate = total ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
            child: Row(
              children: [
                // Qty pill
                _InputPill(
                  width: 80,
                  prefix: 'Qty',
                  child: TextField(
                    controller: _qtyCtrl,
                    onChanged: (v) =>
                        widget.onChanged(qty: double.tryParse(v) ?? 1),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _collapsed('1', context),
                  ),
                ),

                // × separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '×',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // Rate pill — takes remaining space
                Expanded(
                  child: _InputPill(
                    prefix: '₹',
                    child: TextField(
                      controller: _rateCtrl,
                      onChanged: (v) =>
                          widget.onChanged(rate: double.tryParse(v) ?? 0),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _collapsed('rate', context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // = total chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.background(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${_fmtNum(total)}',
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.primary
                          : AppColors.textHint(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── HSN/SAC + Unit (collapsible) ─────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _detailsExpanded ? 'Hide HSN/SAC & unit' : 'Add HSN/SAC & unit',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_detailsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _InputPill(
                      prefix: 'HSN/SAC',
                      child: TextField(
                        controller: _hsnCtrl,
                        onChanged: (v) => widget.onChanged(hsnCode: v),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _collapsed('code', context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InputPill(
                      prefix: 'Unit',
                      child: TextField(
                        controller: _unitCtrl,
                        onChanged: (v) => widget.onChanged(unit: v),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _collapsed('PCS', context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Reusable input pill widget ─────────────────────────────────────────────────

class _InputPill extends StatelessWidget {
  const _InputPill({required this.child, required this.prefix, this.width});

  final Widget child;
  final String prefix;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$prefix ',
          style: TextStyle(
            color: AppColors.textHint(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(child: child),
      ],
    );

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: width != null
          ? inner // fixed width: Row with min mainAxisSize is fine
          : inner, // expanded: parent Expanded handles sizing
    );
  }
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          const Text(
            'Add item',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Tax & Discount Panel ─────────────────────────────────────────────────────

class _TaxDiscountPanel extends StatelessWidget {
  const _TaxDiscountPanel({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: vm.toggleTaxPanel,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.percent_rounded,
                    color: AppColors.textSecondary(context),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tax & discount',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: vm.taxExpanded ? 0.5 : 0,
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

          // Expanded content
          if (vm.taxExpanded) ...[
            Divider(height: 1, color: AppColors.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  // GST %
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'GST %',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ...[0.0, 5.0, 12.0, 18.0, 28.0].map(
                        (pct) => GestureDetector(
                          onTap: () => vm.setGst(pct),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: vm.gstPercent == pct
                                  ? AppColors.primary
                                  : AppColors.background(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: vm.gstPercent == pct
                                    ? AppColors.primary
                                    : AppColors.border(context),
                              ),
                            ),
                            child: Text(
                              pct == 0 ? 'None' : '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: vm.gstPercent == pct
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Discount
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Flat discount (₹)',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          key: ValueKey('discount-${vm.taxExpanded}'),
                          initialValue: vm.discountAmt == 0
                              ? ''
                              : _trimTrailingZero(vm.discountAmt),
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (v) =>
                              vm.setDiscount(double.tryParse(v) ?? 0),
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: AppColors.textHint(context),
                            ),
                            filled: true,
                            fillColor: AppColors.background(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.border(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppColors.border(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Payment mode
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment mode',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: InvoiceCreateViewModel.paymentModes
                        .map(
                          (mode) => GestureDetector(
                            onTap: () => vm.setPaymentMode(mode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: vm.paymentMode == mode
                                    ? AppColors.primary
                                    : AppColors.background(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: vm.paymentMode == mode
                                      ? AppColors.primary
                                      : AppColors.border(context),
                                ),
                              ),
                              child: Text(
                                mode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: vm.paymentMode == mode
                                      ? Colors.white
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _trimTrailingZero(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }
}

// ─── Totals ───────────────────────────────────────────────────────────────────

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.vm});

  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.border(context)),
        const SizedBox(height: 8),
        _TotalRow(
          label: 'Subtotal',
          value: '₹${vm.fmt(vm.subtotal)}',
          labelStyle: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
          valueStyle: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
        ),
        if (vm.gstPercent > 0) ...[
          const SizedBox(height: 4),
          _TotalRow(
            label: 'GST ${vm.gstPercent.toStringAsFixed(0)}%',
            value: '₹${vm.fmt(vm.gstAmt)}',
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
            valueStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
        ],
        if (vm.discountAmt > 0) ...[
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Discount',
            value: '−₹${vm.fmt(vm.discountAmt)}',
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
            valueStyle: TextStyle(color: AppColors.success, fontSize: 13),
          ),
        ],
        if (vm.roundOff != 0) ...[
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Rounded off',
            value:
                '${vm.roundOff > 0 ? '+' : '−'}₹${vm.fmt(vm.roundOff.abs())}',
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
            valueStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _TotalRow(
          label: 'Grand total',
          value: '₹${vm.fmtFull(vm.roundedTotal)}',
          labelStyle: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          valueStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
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
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: AppColors.textSecondary(context),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
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

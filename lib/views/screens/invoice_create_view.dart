import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../viewmodels/client_viewmodel.dart';
import '../../viewmodels/invoice_viewmodel.dart';


class InvoiceCreateView extends StatelessWidget {
  const InvoiceCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InvoiceCreateViewModel(),
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
              onPressed: () => context.pop(),
            ),
            title: Text('New Invoice',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            actions: [
              if (vm.isDraftSaved)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Draft saved',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),

          body: Column(
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
                      ...vm.items.map((item) => _LineItemRow(
                        item: item,
                        onChanged: ({name, qty, rate}) =>
                            vm.updateItem(item.id,
                                name: name, qty: qty, rate: rate),
                        onDelete: () => vm.removeItem(item.id),
                      )),

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
    return Row(children: [
      Expanded(child: _MetaTile(
        label: 'Invoice no.',
        value: vm.invoiceNumber,
        onTap: null, // read-only
      )),
      const SizedBox(width: 12),
      Expanded(child: _MetaTile(
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
                    onSurface: AppColors.textPrimary(ctx)),
              ),
              child: child!,
            ),
          );
          if (picked != null) vm.setDueDate(picked);
        },
      )),
    ]);
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value, this.onTap});
  final String       label;
  final String       value;
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
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
        child: Row(children: [
          if (hasClient) ...[
            _Avatar(name: vm.clientName!),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vm.clientName!,
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (vm.clientEmail != null)
                      Text(vm.clientEmail!,
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 12)),
                  ]),
            ),
            Icon(Icons.swap_horiz_rounded,
                color: AppColors.textSecondary(context), size: 20),
          ] else ...[
            Icon(Icons.person_add_outlined,
                color: AppColors.textSecondary(context), size: 20),
            const SizedBox(width: 10),
            Text('Select client',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 14)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context), size: 18),
          ],
        ]),
      ),
    );
  }

  void _showClientSheet(BuildContext context, InvoiceCreateViewModel vm) {
    final clients = context.read<ClientsViewModel>().clients;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Select Client',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 14),
            Expanded(
              child: clients.isEmpty
                  ? Center(
                  child: Text('No clients yet.',
                      style: TextStyle(
                          color: AppColors.textSecondary(context))))
                  : ListView.separated(
                controller: ctrl,
                itemCount: clients.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AppColors.border(context), height: 1),
                itemBuilder: (_, i) {
                  final c = clients[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Avatar(name: c.name),
                    title: Text(c.name,
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(c.email,
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12)),
                    onTap: () {
                      vm.setClient(
                          id: c.id, name: c.name, email: c.email);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Line Item Row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });
  final LineItem item;
  final void Function({String? name, double? qty, double? rate}) onChanged;
  final VoidCallback onDelete;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.item.name.isEmpty ? '' : widget.item.name);
    _qtyCtrl  = TextEditingController(
        text: widget.item.qty == 1 ? '1' : widget.item.qty.toStringAsFixed(0));
    _rateCtrl = TextEditingController(
        text: widget.item.rate == 0 ? '' : widget.item.rate.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.item.total;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Name row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              onChanged: (v) => widget.onChanged(name: v),
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              decoration: InputDecoration.collapsed(
                hintText: 'Item name',
                hintStyle: TextStyle(
                    color: AppColors.textHint(context),
                    fontWeight: FontWeight.w400),
              ),
            ),
          ),
          Text('₹${_fmtNum(total)}',
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded,
                color: AppColors.textSecondary(context), size: 16),
          ),
        ]),
        const SizedBox(height: 6),

        // Qty × Rate
        Row(children: [
          SizedBox(
            width: 50,
            child: TextField(
              controller: _qtyCtrl,
              onChanged: (v) =>
                  widget.onChanged(qty: double.tryParse(v) ?? 1),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                  color: AppColors.primary, fontSize: 12),
              decoration: InputDecoration.collapsed(hintText: '1'),
            ),
          ),
          Text(' × ',
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 12)),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _rateCtrl,
              onChanged: (v) =>
                  widget.onChanged(rate: double.tryParse(v) ?? 0),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                  color: AppColors.primary, fontSize: 12),
              decoration: InputDecoration.collapsed(hintText: '₹0'),
            ),
          ),
        ]),
      ]),
    );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
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
          color: AppColors.primary.withOpacity(0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        const Text('Add item',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
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
      child: Column(children: [
        // Header row
        InkWell(
          onTap: vm.toggleTaxPanel,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(Icons.percent_rounded,
                  color: AppColors.textSecondary(context), size: 18),
              const SizedBox(width: 10),
              Text('Tax & discount',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              AnimatedRotation(
                turns: vm.taxExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary(context)),
              ),
            ]),
          ),
        ),

        // Expanded content
        if (vm.taxExpanded) ...[
          Divider(height: 1, color: AppColors.border(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(children: [
              // GST %
              Row(children: [
                Expanded(
                  child: Text('GST %',
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13)),
                ),
                ...[0.0, 5.0, 12.0, 18.0, 28.0].map((pct) => GestureDetector(
                  onTap: () => vm.setGst(pct),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: vm.gstPercent == pct
                          ? AppColors.primary
                          : AppColors.background(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: vm.gstPercent == pct
                              ? AppColors.primary
                              : AppColors.border(context)),
                    ),
                    child: Text(
                      pct == 0 ? 'None' : '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: vm.gstPercent == pct
                              ? Colors.white
                              : AppColors.textSecondary(context)),
                    ),
                  ),
                )),
              ]),
              const SizedBox(height: 14),

              // Discount
              Row(children: [
                Expanded(
                  child: Text('Flat discount (₹)',
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13)),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => vm.setDiscount(double.tryParse(v) ?? 0),
                    style: TextStyle(
                        color: AppColors.textPrimary(context), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle:
                      TextStyle(color: AppColors.textHint(context)),
                      filled: true,
                      fillColor: AppColors.background(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Totals ───────────────────────────────────────────────────────────────────

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.vm});
  final InvoiceCreateViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Divider(color: AppColors.border(context)),
      const SizedBox(height: 8),
      _TotalRow(
        label: 'Subtotal',
        value: '₹${vm.fmt(vm.subtotal)}',
        labelStyle: TextStyle(
            color: AppColors.textSecondary(context), fontSize: 13),
        valueStyle: TextStyle(
            color: AppColors.textSecondary(context), fontSize: 13),
      ),
      if (vm.gstPercent > 0) ...[
        const SizedBox(height: 4),
        _TotalRow(
          label: 'GST ${vm.gstPercent.toStringAsFixed(0)}%',
          value: '₹${vm.fmt(vm.gstAmt)}',
          labelStyle: TextStyle(
              color: AppColors.textSecondary(context), fontSize: 13),
          valueStyle: TextStyle(
              color: AppColors.textSecondary(context), fontSize: 13),
        ),
      ],
      if (vm.discountAmt > 0) ...[
        const SizedBox(height: 4),
        _TotalRow(
          label: 'Discount',
          value: '−₹${vm.fmt(vm.discountAmt)}',
          labelStyle: TextStyle(
              color: AppColors.textSecondary(context), fontSize: 13),
          valueStyle: TextStyle(color: AppColors.success, fontSize: 13),
        ),
      ],
      const SizedBox(height: 8),
      _TotalRow(
        label: 'Grand total',
        value: '₹${vm.fmtFull(vm.grandTotal)}',
        labelStyle: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w700),
        valueStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
      ),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });
  final String    label;
  final String    value;
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
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: Row(children: [
        // Preview
        Expanded(
          child: OutlinedButton(
            onPressed: vm.isSaving
                ? null
                : () async {
              await vm.saveDraft();
              if (context.mounted) {
                context.go('/invoices/draft/preview');
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Preview',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),

        // Save & send
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: vm.isSaving
                ? null
                : () async {
              final ok = await vm.saveAndSend();
              if (ok && context.mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: vm.isSaving
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : const Text('Save & send',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      ]),
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
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(message,
            style: const TextStyle(
                color: AppColors.error, fontSize: 13)),
      ),
    ]),
  );
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));
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
      width: 38, height: 38,
      decoration:
      BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Text(_initials,
            style: TextStyle(
                color: c.fg, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
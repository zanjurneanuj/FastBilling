import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/PosPrinter.dart';
import '../../services/PdfTemplateService.dart';
import '../../services/PosPrinterService.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/invoice_status.dart';
import '../../viewmodels/InvoicePreviewViewModel.dart';
import '../widgets/empty_state.dart';
import 'PrintReceiptPreviewView.dart';

// ─── PDF / print actions ────────────────────────────────────────────────────
// Shared by the top-bar print icon and the bottom-bar PDF/Share buttons.

Future<void> _printPdf(BuildContext context, InvoicePreviewViewModel vm) async {
  final inv = vm.invoice;
  if (inv == null) return;
  final doc = await PdfService.buildInvoicePdf(inv, vm.activeTemplate);
  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

Future<void> _sharePdf(BuildContext context, InvoicePreviewViewModel vm) async {
  final inv = vm.invoice;
  if (inv == null) return;
  final doc = await PdfService.buildInvoicePdf(inv, vm.activeTemplate);
  final bytes = await doc.save();
  await Printing.sharePdf(bytes: bytes, filename: '${inv.invoiceNumber}.pdf');
}

void _printReceiptPos(BuildContext context, InvoicePreviewViewModel vm) {
  final inv = vm.invoice;
  if (inv == null) return;

  if (!PosPrinterService.isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connect a printer in Settings first.')));
    return;
  }

  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PrintReceiptPreviewView(
      businessName: inv.senderName.isEmpty ? 'Business' : inv.senderName,
      businessSub: inv.senderAddress,
      invoiceNo: inv.invoiceNumber,
      date: inv.issuedDate,
      billTo: inv.clientName,
      items: inv.items
          .map((i) => PosReceiptLine(name: i.name, qty: i.qty, rate: i.rate))
          .toList(),
      subtotal: inv.subtotal,
      gstAmt: inv.gstAmt,
      total: inv.grandTotal,
      gstPercent: inv.gstPercent,
    ),
  ));
}

class InvoicePreviewView extends StatefulWidget {
  const InvoicePreviewView({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  State<InvoicePreviewView> createState() => _InvoicePreviewViewState();
}

class _InvoicePreviewViewState extends State<InvoicePreviewView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoicePreviewViewModel>().load(widget.invoiceId);
    });
  }

  // Pop back if there's somewhere to pop to (the normal case — reached via
  // push from the list/dashboard); otherwise fall back to the invoices list
  // (e.g. deep-linked directly into this screen with an empty stack).
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/invoices');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoicePreviewViewModel>(
      builder: (context, vm, _) {
        final hasInvoice = vm.invoice != null;
        return Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            backgroundColor: AppColors.surface(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary(context)),
              onPressed: _goBack,
            ),
            title: Text('Preview',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            actions: hasInvoice
                ? [
              IconButton(
                icon: Icon(Icons.print_outlined,
                    color: AppColors.textPrimary(context)),
                onPressed: () => _printPdf(context, vm),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.textPrimary(context)),
                onPressed: () => _showMoreSheet(context, vm),
              ),
            ]
                : null,
          ),
          body: _buildBody(context, vm),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, InvoicePreviewViewModel vm) {
    if (vm.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (vm.notFound) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Invoice not found',
        subtitle: 'This invoice may have been deleted.',
        actionLabel: 'Back to invoices',
        onAction: _goBack,
      );
    }
    if (vm.invoice == null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load invoice',
        subtitle: vm.errorMsg ?? 'Please try again.',
        actionLabel: 'Retry',
        onAction: () => vm.load(widget.invoiceId),
      );
    }
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: _InvoiceCard(vm: vm),
        ),
      ),
      _BottomBar(vm: vm),
    ]);
  }

  void _showMoreSheet(BuildContext context, InvoicePreviewViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          _SheetTile(
            icon: Icons.edit_outlined,
            label: 'Edit invoice',
            onTap: () {
              Navigator.pop(context);
              context.push('/invoices/create', extra: vm.invoice?.id);
            },
          ),
          _SheetTile(
            icon: Icons.style_outlined,
            label: 'Change template',
            onTap: () {
              Navigator.pop(context);
              context.push('/settings/pdf-template');
            },
          ),
          _SheetTile(
            icon: Icons.point_of_sale_outlined,
            label: 'Print receipt (POS)',
            onTap: () {
              Navigator.pop(context);
              _printReceiptPos(context, vm);
            },
          ),
          _SheetTile(
            icon: Icons.content_copy_outlined,
            label: 'Duplicate',
            onTap: () async {
              Navigator.pop(context);
              final newId = await vm.duplicateInvoice();
              if (!context.mounted) return;
              if (newId != null) {
                context.push('/invoices/$newId/preview');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(vm.errorMsg ?? 'Could not duplicate invoice.')));
              }
            },
          ),
          _SheetTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, vm);
            },
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, InvoicePreviewViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete invoice?',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700)),
        content: Text('This action cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await vm.deleteInvoice();
              if (!context.mounted) return;
              if (ok) {
                _goBack();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(vm.errorMsg ?? 'Could not delete invoice.')));
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Invoice Card ─────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.vm});
  final InvoicePreviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final inv = vm.invoice!;

    // ── Active template — every color below comes from here ──────────────
    final t           = PdfTemplateService.selected;
    final headerBg    = t.headerColor;
    final accent      = t.accentColor;
    final isDark      = t.darkHeader;
    final onHeader    = isDark ? Colors.white         : const Color(0xFF1A1A2E);
    final subOnHeader = isDark ? Colors.white70       : const Color(0xFF888888);
    // Card body is always white (PDF paper feel); only header band changes
    const bodyText    = Color(0xFF1A1A2E);
    const mutedText   = Color(0xFF888888);
    const dividerClr  = Color(0xFFEEEEEE);
    const rowBg       = Color(0xFFF8F8FC);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header band — uses template headerColor ────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo / icon — uses template accentColor
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.bolt_rounded,
                    color: isDark ? Colors.white : Colors.white, size: 24),
              ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('INVOICE',
                    style: TextStyle(
                        color: onHeader,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(inv.invoiceNumber,
                    style: TextStyle(color: subOnHeader, fontSize: 12)),
                const SizedBox(height: 6),
                _StatusBadge(status: inv.status),
              ]),
            ],
          ),
        ),

        // ── Sender info ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inv.senderName,
                style: const TextStyle(
                    color: bodyText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            // Sender address uses accent color
            Text(inv.senderAddress,
                style: TextStyle(color: accent, fontSize: 12)),
            Text('GSTIN — ${inv.senderGst ?? 'unregistered'}',
                style: const TextStyle(color: mutedText, fontSize: 12)),
          ]),
        ),

        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Divider(color: dividerClr, height: 1),
        ),

        // ── Bill to + Issued ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BILL TO',
                          style: TextStyle(
                              color: mutedText,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(inv.clientName,
                          style: const TextStyle(
                              color: bodyText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(inv.clientEmail,
                          style: const TextStyle(
                              color: mutedText, fontSize: 12)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('ISSUED',
                    style: TextStyle(
                        color: mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(inv.issuedDate,
                    style: const TextStyle(
                        color: bodyText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Line items table header — uses template accent tint ────────
        Container(
          color: headerBg.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            const Expanded(
              child: Text('DESCRIPTION',
                  style: TextStyle(
                      color: mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
            ),
            const Text('QTY',
                style: TextStyle(
                    color: mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
            const SizedBox(width: 32),
            const Text('AMOUNT',
                style: TextStyle(
                    color: mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ]),
        ),

        // ── Line items — item name uses accent color ───────────────────
        ...inv.items.map((item) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Expanded(
              child: Text(item.name,
                  style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            Text('${item.qty.toStringAsFixed(0)}',
                style: const TextStyle(color: bodyText, fontSize: 13)),
            const SizedBox(width: 16),
            SizedBox(
              width: 70,
              child: Text('₹${_fmt(item.total)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: bodyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        )),

        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: dividerClr, height: 1),
        ),
        const SizedBox(height: 12),

        // ── Subtotals — grand total uses accent color ──────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            _SummaryRow(
              label: 'Subtotal',
              value: '₹${_fmt(inv.subtotal)}',
              labelColor: mutedText,
              valueColor: mutedText,
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'GST ${inv.gstPercent.toStringAsFixed(0)}%',
              value: '₹${_fmt(inv.gstAmt)}',
              labelColor: mutedText,
              valueColor: mutedText,
            ),
            if (inv.discountAmt > 0) ...[
              const SizedBox(height: 4),
              _SummaryRow(
                label: 'Discount',
                value: '−₹${_fmt(inv.discountAmt)}',
                labelColor: mutedText,
                valueColor: AppColors.success,
              ),
            ],
            const SizedBox(height: 10),
            const Divider(color: dividerClr, height: 1),
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'Total',
              value: '₹${_fmtFull(inv.grandTotal)}',
              labelColor: bodyText,
              valueColor: accent,   // ← accent drives the grand total color
              bold: true,
              largeValue: true,
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Footer note ────────────────────────────────────────────────
        if (inv.note != null && inv.note!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: headerBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(inv.note!,
                style: const TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ),

        const SizedBox(height: 20),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  String _fmtFull(double v) {
    final s = v.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final groups = <String>[];
    var r = rest;
    while (r.length > 2) {
      groups.insert(0, r.substring(r.length - 2));
      r = r.substring(0, r.length - 2);
    }
    if (r.isNotEmpty) groups.insert(0, r);
    return '${groups.join(',')},${last3}';
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = InvoiceStatus.badgeColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    this.bold = false,
    this.largeValue = false,
  });
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final bool bold;
  final bool largeValue;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              color: labelColor,
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      Text(value,
          style: TextStyle(
              color: valueColor,
              fontSize: largeValue ? 20 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: largeValue ? -0.5 : 0)),
    ],
  );
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm});
  final InvoicePreviewViewModel vm;

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
        _ActionBtn(
          icon: Icons.download_outlined,
          label: 'PDF',
          onTap: () => _printPdf(context, vm),
        ),
        const SizedBox(width: 10),
        _ActionBtn(
          icon: vm.invoice?.status.toLowerCase() == 'paid'
              ? Icons.remove_circle_outline_rounded
              : Icons.check_circle_outline_rounded,
          label: vm.invoice?.status.toLowerCase() == 'paid' ? 'Unpaid' : 'Paid',
          iconColor: vm.invoice?.status.toLowerCase() == 'paid'
              ? AppColors.error
              : AppColors.success,
          labelColor: vm.invoice?.status.toLowerCase() == 'paid'
              ? AppColors.error
              : AppColors.success,
          onTap: () => vm.togglePaidStatus(),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _sharePdf(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
            label: const Text('Share',
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 70,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: iconColor ?? AppColors.textSecondary(context), size: 20),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: labelColor ?? AppColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

// ─── Sheet Tile ───────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon,
        color: color ?? AppColors.textPrimary(context), size: 22),
    title: Text(label,
        style: TextStyle(
            color: color ?? AppColors.textPrimary(context),
            fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
}
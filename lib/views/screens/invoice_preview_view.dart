import 'package:flutter/material.dart';
import '../../utils/invoice_share_message.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
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
import 'section_arrange_view.dart';
import '../widgets/cached_pdf_preview.dart';
import '../../utils/app_features.dart';

// ─── PDF / print actions ────────────────────────────────────────────────────
// Shared by the top-bar print icon and the bottom-bar PDF/Share buttons.

Future<void> _printPdf(BuildContext context, InvoicePreviewViewModel vm) async {
  final inv = vm.invoice;
  if (inv == null) return;
  final bytes = await PdfService.buildInvoicePdfBytes(
    inv,
    vm.activeTemplate,
    sections: PdfTemplateService.sections,
  );
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

/// Share opens a sheet with a ready-made message (amount, due date, UPI /
/// bank details) the user can edit, then sends the PDF *with* that message
/// — on WhatsApp the text becomes the document's caption.
Future<void> _sharePdf(BuildContext context, InvoicePreviewViewModel vm) async {
  final inv = vm.invoice;
  if (inv == null) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ShareSheet(vm: vm),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.vm});
  final InvoicePreviewViewModel vm;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late final _msg = TextEditingController(
    text: InvoiceShareMessage.build(widget.vm.invoice!),
  );
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final inv = widget.vm.invoice!;
    setState(() => _busy = true);
    try {
      final bytes = await PdfService.buildInvoicePdfBytes(
        inv,
        widget.vm.activeTemplate,
        sections: PdfTemplateService.sections,
      );
      final dir = await getTemporaryDirectory();
      final safe = inv.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/$safe.pdf');
      await file.writeAsBytes(bytes, flush: true);

      // Some apps drop the caption on documents — keep it on the clipboard
      // so it can be pasted straight after.
      await Clipboard.setData(ClipboardData(text: _msg.text));
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: '$safe.pdf')],
        text: _msg.text,
        subject: 'Invoice ${inv.invoiceNumber}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share the invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Share on WhatsApp',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'The PDF is sent with this message — edit it if you like.',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: TextField(
                controller: _msg,
                maxLines: null,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _send,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                    label: const Text(
                      'Send PDF + message',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _printReceiptPos(BuildContext context, InvoicePreviewViewModel vm) {
  final inv = vm.invoice;
  if (inv == null) return;

  if (!PosPrinterService.isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connect a printer in Settings first.')),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PrintReceiptPreviewView(
        businessName: inv.senderName.isEmpty ? 'Business' : inv.senderName,
        businessSub: inv.senderAddress,
        invoiceNo: inv.invoiceNumber,
        date: inv.issuedDate,
        billTo: inv.clientName,
        items: inv.items
            // Discounted taxable value, so lines add up to the subtotal.
            .map(
              (i) => PosReceiptLine(
                name: i.name,
                qty: i.qty,
                rate: i.rate,
                amount: i.total,
              ),
            )
            .toList(),
        subtotal: inv.subtotal,
        gstAmt: inv.gstAmt,
        total: inv.roundedTotal,
        gstPercent: inv.gstPercent,
      ),
    ),
  );
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
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary(context),
              ),
              onPressed: _goBack,
            ),
            title: Text(
              'Preview',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: hasInvoice
                ? [
                    IconButton(
                      icon: Icon(
                        Icons.print_outlined,
                        color: AppColors.textPrimary(context),
                      ),
                      onPressed: () => _printPdf(context, vm),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textPrimary(context),
                      ),
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
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
    return Column(
      children: [
        Expanded(child: _InvoicePdfView(vm: vm)),
        _BottomBar(vm: vm),
      ],
    );
  }

  void _showMoreSheet(BuildContext context, InvoicePreviewViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (AppFeatures.posPrinter)
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        vm.errorMsg ?? 'Could not duplicate invoice.',
                      ),
                    ),
                  );
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
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, InvoicePreviewViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete invoice?',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await vm.deleteInvoice();
              if (!context.mounted) return;
              if (ok) {
                _goBack();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(vm.errorMsg ?? 'Could not delete invoice.'),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Invoice PDF ──────────────────────────────────────────────────────────────
// Shows the real generated PDF (not a hand-drawn imitation), so what the user
// sees here is exactly what gets printed or shared, in the active template.

class _InvoicePdfView extends StatelessWidget {
  const _InvoicePdfView({required this.vm});
  final InvoicePreviewViewModel vm;

  @override
  Widget build(BuildContext context) {
    final inv = vm.invoice!;
    final t = vm.activeTemplate;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              _StatusBadge(status: inv.status),
              const Spacer(),
              ActionChip(
                avatar: const Icon(
                  Icons.dashboard_customize_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Arrange',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side: BorderSide.none,
                onPressed: () =>
                    openSectionArranger(context, invoice: inv, template: t),
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: Icon(
                  Icons.style_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  t.name,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side: BorderSide.none,
                onPressed: () => context.push('/settings/pdf-template'),
              ),
            ],
          ),
        ),
        Expanded(
          child: CachedPdfPreview(
            // Regenerate only when the template, status or layout changes.
            cacheKey:
                '${t.id}-${inv.status}-'
                '${PdfTemplateService.sections.toJson()}',
            build: () => PdfService.buildInvoicePdfBytes(
              inv,
              t,
              sections: PdfTemplateService.sections,
            ),
          ),
        ),
      ],
    );
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm});
  final InvoicePreviewViewModel vm;

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
            label: vm.invoice?.status.toLowerCase() == 'paid'
                ? 'Unpaid'
                : 'Paid',
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Share',
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
          Icon(
            icon,
            color: iconColor ?? AppColors.textSecondary(context),
            size: 20,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? AppColors.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
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
    leading: Icon(
      icon,
      color: color ?? AppColors.textPrimary(context),
      size: 22,
    ),
    title: Text(
      label,
      style: TextStyle(
        color: color ?? AppColors.textPrimary(context),
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: onTap,
  );
}

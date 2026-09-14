import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../models/InvoiceDetail.dart';
import '../../models/InvoiceLineItem.dart';
import '../../models/PdfTemplate.dart';
import '../../services/PdfTemplateService.dart';
import '../../services/ProfileService.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_colors.dart';

class PdfTemplateView extends StatefulWidget {
  const PdfTemplateView({super.key});

  @override
  State<PdfTemplateView> createState() => _PdfTemplateViewState();
}

class _PdfTemplateViewState extends State<PdfTemplateView> {
  late PdfTemplate _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = PdfTemplateService.selected;
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    await PdfTemplateService.select(_selected);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selected.name} template applied'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      context.pop();
    }
  }

  /// A representative invoice for the live preview — real business profile
  /// (name/address/GSTIN) with a generic sample client and line items,
  /// since template selection isn't tied to any one real invoice.
  InvoiceDetail _sampleInvoice() {
    final profile = ProfileService.cached;
    return InvoiceDetail(
      id: 'sample',
      invoiceNumber: 'INV-${DateTime.now().year}-001',
      status: 'sent',
      senderName: profile?.name ?? 'Your Business',
      senderAddress: profile?.address ?? '',
      senderGst: profile?.gstNumber,
      senderState: profile?.state,
      senderBankName: profile?.bankName,
      senderBankAccountNo: profile?.bankAccountNo,
      senderBankIfsc: profile?.bankIfsc,
      clientName: 'Sample Client',
      clientEmail: 'client@example.com',
      issuedDate: DateFormat('d MMM yyyy').format(DateTime.now()),
      items: const [
        InvoiceLineItem(name: 'Consulting services', qty: 10, rate: 1500, unit: 'HRS'),
        InvoiceLineItem(name: 'Design work', qty: 1, rate: 8000, hsnCode: '998314'),
      ],
      gstPercent: 18,
      discountAmt: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Invoice template',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Live preview of the real generated PDF ───────────────────────
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: PdfPreview(
                key: ValueKey(_selected.id),
                build: (format) async {
                  final doc = await PdfService.buildInvoicePdf(
                      _sampleInvoice(), _selected);
                  return doc.save();
                },
                useActions: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
          ),

          // ── Template picker ───────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text(
                  'Choose a layout for your PDF invoices.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: PdfTemplateCatalog.all.length,
                  itemBuilder: (context, i) {
                    final t = PdfTemplateCatalog.all[i];
                    final isSelected = _selected.id == t.id;
                    return _TemplateSwatch(
                      template: t,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = t),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Apply button ───────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(
                  top: BorderSide(color: AppColors.border(context))),
            ),
            child: ElevatedButton(
              onPressed: _saving ? null : _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
                  : const Text(
                'Apply template',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Template swatch (color + name, not a fake invoice mockup) ────────────────

class _TemplateSwatch extends StatelessWidget {
  const _TemplateSwatch({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final PdfTemplate  template;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: template.headerColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: template.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    template.description,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

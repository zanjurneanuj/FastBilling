import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/PdfTemplate.dart';
import '../../services/PdfTemplateService.dart';
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
          // ── Template grid ──────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                Text(
                  'Choose a layout for your PDF invoices.',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: PdfTemplateCatalog.all.length,
                  itemBuilder: (context, i) {
                    final t = PdfTemplateCatalog.all[i];
                    final isSelected = _selected.id == t.id;
                    return _TemplateCard(
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

// ─── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
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
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mini invoice preview ─────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
                child: _MiniPreview(template: template),
              ),
            ),

            // ── Label row ────────────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.description,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini Invoice Preview ─────────────────────────────────────────────────────

class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.template});
  final PdfTemplate template;

  @override
  Widget build(BuildContext context) {
    final accent = template.accentColor;
    final header = template.headerColor;
    final isDark = template.darkHeader;
    final textOnHeader = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subOnHeader  = isDark
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF888888);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: header,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent bar
                Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                _MiniText('INVOICE', color: textOnHeader,
                    fontSize: 7, bold: true),
                const SizedBox(height: 2),
                _MiniText('Business Name', color: subOnHeader,
                    fontSize: 5),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Bill to row
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniText('BILL TO', color: const Color(0xFF888888),
                      fontSize: 4, bold: true),
                  const SizedBox(height: 2),
                  _MiniText('Client Name',
                      color: const Color(0xFF1A1A2E), fontSize: 5),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniText('AMOUNT DUE',
                    color: const Color(0xFF888888),
                    fontSize: 4, bold: true),
                const SizedBox(height: 2),
                _MiniText('₹ 0,000',
                    color: accent, fontSize: 6, bold: true),
              ],
            ),
          ]),
          const SizedBox(height: 6),

          // Line items stub
          Container(
            height: 1,
            color: const Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 4),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          )),
          const SizedBox(height: 4),
          Container(height: 1, color: const Color(0xFFEEEEEE)),
          const SizedBox(height: 4),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniText('Total',
                  color: const Color(0xFF1A1A2E),
                  fontSize: 5, bold: true),
              _MiniText('₹ 0,000',
                  color: accent, fontSize: 6, bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniText extends StatelessWidget {
  const _MiniText(
      this.text, {
        required this.color,
        required this.fontSize,
        this.bold = false,
      });
  final String text;
  final Color  color;
  final double fontSize;
  final bool   bold;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      height: 1.2,
    ),
  );
}
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../models/PdfTemplate.dart';
import '../../services/PdfTemplateService.dart';
import '../../services/ProfileService.dart';
import '../../services/SubscriptionService.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/sample_invoice.dart';
import '../../utils/template_gate.dart';
import 'custom_template_view.dart';
import 'section_arrange_view.dart';
import '../widgets/cached_pdf_preview.dart';

/// "Select a Template" — tabs of real rendered thumbnails. Tapping a card
/// selects it (Pro ones go through the Razorpay unlock first); tapping the
/// selected card again opens a full-size preview; Save applies it.
class PdfTemplateView extends StatefulWidget {
  const PdfTemplateView({super.key});

  @override
  State<PdfTemplateView> createState() => _PdfTemplateViewState();
}

class _PdfTemplateViewState extends State<PdfTemplateView> {
  late PdfTemplate _selected = PdfTemplateService.effective;
  bool _saving = false;

  static const _tabs = <(String, List<PdfTemplate> Function())>[
    ('Recommended', _recommended),
    ('Simple', _simple),
    ('Classic', _classic),
    ('Professional', _professional),
    ('My templates', _mine),
  ];
  static List<PdfTemplate> _mine() => PdfTemplateService.customTemplates;

  @override
  void initState() {
    super.initState();
    PdfTemplateService.changed.addListener(_refresh);
  }

  @override
  void dispose() {
    PdfTemplateService.changed.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _selected = PdfTemplateService.resolve(_selected.id));
  }

  Future<void> _createOrEdit([PdfTemplate? editing]) async {
    final t = await openTemplateBuilder(context, editing: editing);
    if (t != null && mounted) setState(() => _selected = t);
  }

  Future<void> _arrange() async {
    await openSectionArranger(context,
        invoice: SampleInvoice.build(ProfileService.cached), template: _selected);
    if (mounted) setState(() {}); // thumbnails pick up the new arrangement
  }
  static List<PdfTemplate> _recommended() => PdfTemplateCatalog.recommended;
  static List<PdfTemplate> _simple() =>
      PdfTemplateCatalog.inCategory(TemplateCategory.simple);
  static List<PdfTemplate> _classic() =>
      PdfTemplateCatalog.inCategory(TemplateCategory.classic);
  static List<PdfTemplate> _professional() =>
      PdfTemplateCatalog.inCategory(TemplateCategory.professional);

  Future<void> _onTap(PdfTemplate t) async {
    if (t.id == _selected.id) {
      _openFullPreview(t);
      return;
    }
    if (t.isPro && !SubscriptionService.isPremium) {
      final unlocked = await unlockProTemplates(context);
      if (!mounted) return;
      if (!unlocked) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pro templates unlocked — enjoy!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ));
    }
    setState(() => _selected = t);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await PdfTemplateService.select(_selected);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected.name} template applied'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
    context.pop();
  }

  void _openFullPreview(PdfTemplate t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(t.name)),
        body: CachedPdfPreview(
          cacheKey: t.id,
          build: () => PdfService.buildInvoicePdfBytes(
              SampleInvoice.build(ProfileService.cached), t,
              sections: PdfTemplateService.sections),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
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
            'Select a Template',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Arrange sections',
              icon: Icon(Icons.dashboard_customize_outlined,
                  color: AppColors.textPrimary(context)),
              onPressed: _arrange,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.textPrimary(context),
            unselectedLabelColor: AppColors.textSecondary(context),
            labelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            indicatorColor: AppColors.primary,
            dividerColor: AppColors.border(context),
            tabs: [for (final (name, _) in _tabs) Tab(text: name)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final (_, list) in _tabs)
              GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: list().length + (list == _mine ? 1 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  // A4 page (1 : 1.414) plus the name row underneath.
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (_, i) {
                  if (list == _mine) {
                    if (i == 0) return _CreateTile(onTap: () => _createOrEdit());
                    i -= 1;
                  }
                  final t = list()[i];
                  return _TemplateTile(
                    template: t,
                    selected: t.id == _selected.id,
                    locked: t.isPro && !SubscriptionService.isPremium,
                    onTap: () => _onTap(t),
                    onEdit: t.isCustom ? () => _createOrEdit(t) : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.onEdit,
  });

  final PdfTemplate template;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border(context),
                  width: selected ? 2.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateThumbnail(template: template),
                  if (template.isPro)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _ProBadge(locked: locked),
                    ),
                  if (onEdit != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit template',
                          icon: const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.primary),
                          onPressed: onEdit,
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Selected · tap to preview',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.locked});
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFC155), Color(0xFFF7931E)],
      ),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (locked) ...[
          const Icon(Icons.lock_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 3),
        ],
        const Text('PRO',
            style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic)),
      ],
    ),
  );
}

/// First page of the template rendered with the sample invoice, cached
/// per template for the session.
class TemplateThumbnail extends StatelessWidget {
  const TemplateThumbnail({required this.template});
  final PdfTemplate template;

  static final Map<String, Future<Uint8List>> _cache = {};

  static Future<Uint8List> _render(PdfTemplate t) async {
    // PDF layout runs on a background isolate; rasterising is native.
    final bytes = await PdfService.buildInvoicePdfBytes(
        SampleInvoice.build(ProfileService.cached), t,
        sections: PdfTemplateService.sections);
    final page = await Printing.raster(bytes, pages: const [0], dpi: 60).first;
    return page.toPng();
  }

  @override
  Widget build(BuildContext context) {
    final key = '${template.id}-${template.layout.name}-'
        '${template.accentColor.toARGB32()}-'
        '${ProfileService.cached?.updatedAt ?? 0}-'
        '${PdfTemplateService.sections.toJson()}';
    return FutureBuilder<Uint8List>(
      future: _cache.putIfAbsent(key, () => _render(template)),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!,
              fit: BoxFit.cover, alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium);
        }
        if (snap.hasError) {
          return Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textHint(context)));
        }
        return Container(
          color: template.headerColor,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: template.accentColor),
          ),
        );
      },
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 38, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Create template',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('Your layout, your colours',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.primary, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('New',
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Text('Design your own',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
        ],
      ),
    );
  }
}

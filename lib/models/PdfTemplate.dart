import 'package:flutter/material.dart';

/// The distinct page structures PdfService knows how to draw. Several
/// catalog entries share a layout and differ only in color.
enum TemplateLayout {
  /// Big "INVOICE" title, FROM / BILL TO columns, accent table header.
  simple,

  /// Logo + seller top-left, accent "INVOICE" top-right.
  logoHeader,

  /// Full-width color band across the top with a white title.
  banner,

  /// Arrow-shaped color tag holding the title.
  ribbon,

  /// Bordered GST tax-invoice grid — the format Indian traders print.
  gstClassic,

  /// Diagonal color blocks in the corners.
  diagonal,

  /// Dark page with the invoice on a white card.
  darkCard,
}

enum TemplateCategory { simple, classic, professional, custom }

/// Describes one invoice PDF layout option.
///
/// `id` is the stable key that gets persisted (Firestore + local cache).
class PdfTemplate {
  final String id;
  final String name;
  final String description;
  final TemplateLayout layout;
  final TemplateCategory category;
  final Color headerColor;
  final Color accentColor;
  final bool darkHeader;

  /// Pro templates need Premium — unlocked via Razorpay checkout.
  final bool isPro;

  bool get isCustom => category == TemplateCategory.custom;

  /// A user-made template: any layout in any accent color.
  factory PdfTemplate.custom({
    required String id,
    required String name,
    required TemplateLayout layout,
    required Color accent,
  }) {
    final dark = accent.computeLuminance() < 0.4;
    return PdfTemplate(
      id: id,
      name: name,
      description: 'My template · ${layoutNames[layout]}',
      layout: layout,
      category: TemplateCategory.custom,
      // Light tint of the accent for panels / thumbnails' placeholder.
      headerColor: Color.lerp(accent, Colors.white, 0.88)!,
      accentColor: accent,
      darkHeader: dark,
      // Designing your own template is a Premium feature.
      isPro: true,
    );
  }

  static const layoutNames = {
    TemplateLayout.simple: 'Simple',
    TemplateLayout.logoHeader: 'Logo header',
    TemplateLayout.banner: 'Banner',
    TemplateLayout.ribbon: 'Ribbon',
    TemplateLayout.gstClassic: 'GST grid',
    TemplateLayout.diagonal: 'Diagonal',
    TemplateLayout.darkCard: 'Dark card',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'layout': layout.name,
    'accent': accentColor.toARGB32(),
  };

  static PdfTemplate? fromJson(Map<String, dynamic> j) {
    final layout = TemplateLayout.values
        .where((l) => l.name == j['layout'])
        .firstOrNull;
    final id = j['id'] as String?;
    if (layout == null || id == null) return null;
    return PdfTemplate.custom(
      id: id,
      name: (j['name'] as String?) ?? 'My template',
      layout: layout,
      accent: Color((j['accent'] as num?)?.toInt() ?? 0xFF4F46E5),
    );
  }

  const PdfTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.layout,
    required this.category,
    required this.headerColor,
    required this.accentColor,
    this.darkHeader = false,
    this.isPro = false,
  });
}

/// Built-in catalog. Add new templates here — they show up in the picker
/// automatically; a new [TemplateLayout] also needs a builder in PdfService.
class PdfTemplateCatalog {
  PdfTemplateCatalog._();

  // ── Simple (free) ─────────────────────────────────────────────────────────
  static const minimal = PdfTemplate(
    id: 'minimal',
    name: 'Minimal',
    description: 'Ultra-clean, black & white',
    layout: TemplateLayout.simple,
    category: TemplateCategory.simple,
    headerColor: Colors.white,
    accentColor: Color(0xFF111111),
  );

  static const modern = PdfTemplate(
    id: 'modern',
    name: 'Modern',
    description: 'Logo header, indigo accent',
    layout: TemplateLayout.logoHeader,
    category: TemplateCategory.simple,
    headerColor: Color(0xFFEDEBFF),
    accentColor: Color(0xFF4F46E5),
  );

  static const emerald = PdfTemplate(
    id: 'emerald',
    name: 'Emerald',
    description: 'Green accent, fresh look',
    layout: TemplateLayout.simple,
    category: TemplateCategory.simple,
    headerColor: Color(0xFFE6F4EA),
    accentColor: Color(0xFF2E9E4F),
  );

  static const slate = PdfTemplate(
    id: 'slate',
    name: 'Slate',
    description: 'Cool grey, understated',
    layout: TemplateLayout.logoHeader,
    category: TemplateCategory.simple,
    headerColor: Color(0xFFECEFF1),
    accentColor: Color(0xFF546E7A),
  );

  static const sunset = PdfTemplate(
    id: 'sunset',
    name: 'Sunset',
    description: 'Orange ribbon title',
    layout: TemplateLayout.ribbon,
    category: TemplateCategory.simple,
    headerColor: Color(0xFFFFF1E6),
    accentColor: Color(0xFFF59E0B),
  );

  static const bold = PdfTemplate(
    id: 'bold',
    name: 'Bold',
    description: 'Black banner, high impact',
    layout: TemplateLayout.banner,
    category: TemplateCategory.simple,
    headerColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFF1A1A1A),
    darkHeader: true,
  );

  // ── Classic GST (free) ────────────────────────────────────────────────────
  static const classic = PdfTemplate(
    id: 'classic',
    name: 'GST Classic',
    description: 'Bordered tax invoice, B&W',
    layout: TemplateLayout.gstClassic,
    category: TemplateCategory.classic,
    headerColor: Colors.white,
    accentColor: Colors.black,
  );

  static const ink = PdfTemplate(
    id: 'ink',
    name: 'GST Navy',
    description: 'Bordered tax invoice, navy',
    layout: TemplateLayout.gstClassic,
    category: TemplateCategory.classic,
    headerColor: Color(0xFFE8ECF6),
    accentColor: Color(0xFF1B2A4A),
  );

  static const gstMaroon = PdfTemplate(
    id: 'gst_maroon',
    name: 'GST Maroon',
    description: 'Bordered tax invoice, maroon',
    layout: TemplateLayout.gstClassic,
    category: TemplateCategory.classic,
    headerColor: Color(0xFFF7E9EA),
    accentColor: Color(0xFF8E2430),
  );

  // ── Professional (Pro) ────────────────────────────────────────────────────
  static const midnight = PdfTemplate(
    id: 'pro_midnight',
    name: 'Midnight',
    description: 'Navy page, white card',
    layout: TemplateLayout.darkCard,
    category: TemplateCategory.professional,
    headerColor: Color(0xFF1F2A5A),
    accentColor: Color(0xFF1F2A5A),
    darkHeader: true,
    isPro: true,
  );

  static const royal = PdfTemplate(
    id: 'pro_royal',
    name: 'Royal',
    description: 'Deep purple, white card',
    layout: TemplateLayout.darkCard,
    category: TemplateCategory.professional,
    headerColor: Color(0xFF3B2177),
    accentColor: Color(0xFF3B2177),
    darkHeader: true,
    isPro: true,
  );

  static const edge = PdfTemplate(
    id: 'pro_edge',
    name: 'Edge',
    description: 'Green diagonal corners',
    layout: TemplateLayout.diagonal,
    category: TemplateCategory.professional,
    headerColor: Color(0xFF16C172),
    accentColor: Color(0xFF16C172),
    darkHeader: true,
    isPro: true,
  );

  static const steel = PdfTemplate(
    id: 'pro_steel',
    name: 'Steel',
    description: 'Steel-blue diagonal corners',
    layout: TemplateLayout.diagonal,
    category: TemplateCategory.professional,
    headerColor: Color(0xFF234E70),
    accentColor: Color(0xFF234E70),
    darkHeader: true,
    isPro: true,
  );

  static const crimson = PdfTemplate(
    id: 'pro_crimson',
    name: 'Crimson',
    description: 'Red banner, bold totals',
    layout: TemplateLayout.banner,
    category: TemplateCategory.professional,
    headerColor: Color(0xFFC62828),
    accentColor: Color(0xFFC62828),
    darkHeader: true,
    isPro: true,
  );

  // Free — the 10th free template, so new users get one of every layout
  // family (keeps its original id so saved selections still resolve).
  static const ocean = PdfTemplate(
    id: 'pro_ocean',
    name: 'Ocean',
    description: 'Blue ribbon title',
    layout: TemplateLayout.ribbon,
    category: TemplateCategory.professional,
    headerColor: Color(0xFFE3F0FF),
    accentColor: Color(0xFF1565C0),
  );

  /// Shown in the Settings quick-pick sheet.
  static const List<PdfTemplate> quickPick = [modern, classic, midnight, edge];

  /// First tab of the picker — a mix across categories.
  static const List<PdfTemplate> recommended = [
    modern, classic, midnight, edge, emerald, crimson, ink, sunset,
  ];

  static const List<PdfTemplate> all = [
    minimal, modern, emerald, slate, sunset, bold,
    classic, ink, gstMaroon,
    midnight, royal, edge, steel, crimson, ocean,
  ];

  /// Templates included in the free plan.
  static List<PdfTemplate> get free => all.where((t) => !t.isPro).toList();

  static List<PdfTemplate> inCategory(TemplateCategory c) =>
      all.where((t) => t.category == c).toList();

  static PdfTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => modern);
}

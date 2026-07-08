import 'package:flutter/material.dart';

/// Describes one invoice PDF layout option.
///
/// `id` is the stable key that gets persisted (Firestore + local cache) and
/// is what your PDF generator should switch on when laying out the invoice.
class PdfTemplate {
  final String id;
  final String name;
  final String description;
  final Color headerColor;
  final Color accentColor;
  final bool darkHeader;

  const PdfTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.headerColor,
    required this.accentColor,
    this.darkHeader = false,
  });
}

/// Built-in catalog. The first 4 are what show in the quick-pick dialog;
/// the full list (including these) shows on the "See more templates" page.
/// Add new templates here — nothing else needs to change to make them
/// selectable, they just need a matching branch in your PDF generator.
class PdfTemplateCatalog {
  PdfTemplateCatalog._();

  static const modern = PdfTemplate(
    id: 'modern',
    name: 'Modern',
    description: 'Clean lines, accent bar',
    headerColor: Color(0xFFEDEBFF),
    accentColor: Color(0xFF5B4FE9),
  );

  static const classic = PdfTemplate(
    id: 'classic',
    name: 'Classic',
    description: 'B&W, professional',
    headerColor: Colors.white,
    accentColor: Colors.black,
  );

  static const bold = PdfTemplate(
    id: 'bold',
    name: 'Bold',
    description: 'Dark header, high impact',
    headerColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFF1A1A1A),
    darkHeader: true,
  );

  static const minimal = PdfTemplate(
    id: 'minimal',
    name: 'Minimal',
    description: 'Ultra-clean, no frills',
    headerColor: Colors.white,
    accentColor: Color(0xFFBDBDBD),
  );

  static const slate = PdfTemplate(
    id: 'slate',
    name: 'Slate',
    description: 'Cool grey, understated',
    headerColor: Color(0xFFECEFF1),
    accentColor: Color(0xFF546E7A),
  );

  static const emerald = PdfTemplate(
    id: 'emerald',
    name: 'Emerald',
    description: 'Green accent, fresh look',
    headerColor: Color(0xFFE6F4EA),
    accentColor: Color(0xFF1E8E3E),
  );

  static const sunset = PdfTemplate(
    id: 'sunset',
    name: 'Sunset',
    description: 'Warm orange highlight',
    headerColor: Color(0xFFFFF1E6),
    accentColor: Color(0xFFE8641C),
  );

  static const ink = PdfTemplate(
    id: 'ink',
    name: 'Ink',
    description: 'Navy header, formal tone',
    headerColor: Color(0xFF1B2A4A),
    accentColor: Color(0xFF1B2A4A),
    darkHeader: true,
  );

  /// Shown in the quick-pick dialog.
  static const List<PdfTemplate> quickPick = [modern, classic, bold, minimal];

  /// Shown on the full "browse templates" page.
  static const List<PdfTemplate> all = [
    modern, classic, bold, minimal, slate, emerald, sunset, ink,
  ];

  static PdfTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => modern);
}
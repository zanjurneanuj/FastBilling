import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/InvoiceSection.dart';
import '../models/PdfTemplate.dart';
import 'SubscriptionService.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

/// Persists the user's invoice look: which PDF template is selected, the
/// order/visibility of invoice sections, and their own custom templates.
/// SQLite (LocalDbService) is the fast local cache; Firestore
/// (`business_profiles/{uid}`) syncs it across devices.
class PdfTemplateService {
  PdfTemplateService._();

  static const _templateKey = 'pdf_template_id';
  static const _sectionsKey = 'pdf_section_layout';
  static const _customKey = 'pdf_custom_templates';
  static const _collection = 'business_profiles';

  static PdfTemplate _selected = PdfTemplateCatalog.modern;
  static PdfTemplate get selected => _selected;

  static SectionLayout _sections = SectionLayout.standard;
  static SectionLayout get sections => _sections;

  static List<PdfTemplate> _custom = [];
  static List<PdfTemplate> get customTemplates => List.unmodifiable(_custom);

  /// The template invoices are actually rendered with: the selection, unless
  /// it's a Pro template on an account that isn't Premium (e.g. picked on
  /// another device, or Premium lapsed) — then the free default.
  static PdfTemplate get effective =>
      (_selected.isPro && !SubscriptionService.isPremium)
          ? PdfTemplateCatalog.modern
          : _selected;

  static final ValueNotifier<int> changed = ValueNotifier(0);

  /// Built-in or custom template by id; falls back to the default.
  static PdfTemplate resolve(String id) {
    for (final t in _custom) {
      if (t.id == id) return t;
    }
    return PdfTemplateCatalog.byId(id);
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Local SQLite only — fast and offline-safe, so startup can await it.
  static Future<void> loadLocal() async {
    try {
      final db = LocalDbService.instance;
      final custom = await db.getSetting(_customKey);
      if (custom != null) _custom = _decodeCustom(jsonDecode(custom));
      final sections = await db.getSetting(_sectionsKey);
      if (sections != null) {
        _sections = SectionLayout.fromJson(
            Map<String, dynamic>.from(jsonDecode(sections) as Map));
      }
      final id = await db.getSetting(_templateKey);
      if (id != null) _selected = resolve(id);
      changed.value++;
    } catch (e) {
      debugPrint('[PdfTemplate] SQLite load failed: $e');
    }
  }

  /// Reconciles with Firestore in case anything changed on another device.
  /// Safe to run in the background after startup.
  static Future<void> syncFromCloud() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final db = LocalDbService.instance;

      if (data['customTemplates'] is List) {
        _custom = _decodeCustom(data['customTemplates']);
        await db.saveSetting(_customKey, jsonEncode(_encodeCustom()));
      }
      if (data['sectionLayout'] is Map) {
        _sections = SectionLayout.fromJson(
            Map<String, dynamic>.from(data['sectionLayout'] as Map));
        await db.saveSetting(_sectionsKey, jsonEncode(_sections.toJson()));
      }
      final cloudId = data['pdfTemplate'] as String?;
      if (cloudId != null) {
        _selected = resolve(cloudId);
        await db.saveSetting(_templateKey, cloudId);
      }
      changed.value++;
    } catch (e) {
      debugPrint('[PdfTemplate] Firestore load failed: $e');
    }
  }

  /// Back to defaults and drop the local cache — on sign-out, so the next
  /// account on this device starts clean.
  static Future<void> reset() async {
    _selected = PdfTemplateCatalog.modern;
    _sections = SectionLayout.standard;
    _custom = [];
    changed.value++;
    try {
      final db = LocalDbService.instance;
      for (final k in [_templateKey, _sectionsKey, _customKey]) {
        await db.deleteSetting(k);
      }
    } catch (e) {
      debugPrint('[PdfTemplate] local reset failed: $e');
    }
  }

  /// Both steps — kept for callers that just want everything loaded.
  static Future<void> load() async {
    await loadLocal();
    await syncFromCloud();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Called when the user taps "Save" on the template picker.
  static Future<void> select(PdfTemplate template) async {
    _selected = template;
    changed.value++; // update UI immediately
    await _persist(_templateKey, template.id, {'pdfTemplate': template.id});
  }

  static Future<void> saveSections(SectionLayout layout) async {
    _sections = layout;
    changed.value++;
    await _persist(_sectionsKey, jsonEncode(layout.toJson()),
        {'sectionLayout': layout.toJson()});
  }

  /// Adds or replaces a custom template.
  static Future<void> saveCustom(PdfTemplate template) async {
    final i = _custom.indexWhere((t) => t.id == template.id);
    _custom = [..._custom];
    if (i == -1) {
      _custom.add(template);
    } else {
      _custom[i] = template;
    }
    if (_selected.id == template.id) _selected = template;
    changed.value++;
    await _persistCustom();
  }

  static Future<void> deleteCustom(String id) async {
    _custom = _custom.where((t) => t.id != id).toList();
    if (_selected.id == id) {
      await select(PdfTemplateCatalog.modern);
    } else {
      changed.value++;
    }
    await _persistCustom();
  }

  static Future<void> _persistCustom() => _persist(
      _customKey, jsonEncode(_encodeCustom()), {'customTemplates': _encodeCustom()});

  static List<Map<String, dynamic>> _encodeCustom() =>
      _custom.map((t) => t.toJson()).toList();

  static List<PdfTemplate> _decodeCustom(Object? raw) => [
        for (final j in (raw as List<dynamic>? ?? []))
          if (j is Map)
            if (PdfTemplate.fromJson(Map<String, dynamic>.from(j)) case final t?) t,
      ];

  static Future<void> _persist(
      String localKey, String localValue, Map<String, Object?> cloud) async {
    try {
      await LocalDbService.instance.saveSetting(localKey, localValue);
    } catch (e) {
      debugPrint('[PdfTemplate] SQLite save failed: $e');
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .set(cloud, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PdfTemplate] Firestore save failed: $e — will reconcile on next load');
    }
  }
}

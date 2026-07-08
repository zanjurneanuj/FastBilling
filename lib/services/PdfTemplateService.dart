import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/PdfTemplate.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

/// Persists which invoice PDF template the user has picked.
/// Uses SQLite (LocalDbService) as local cache instead of SharedPreferences,
/// then reconciles with Firestore for cross-device sync.
class PdfTemplateService {
  PdfTemplateService._();

  static const _settingKey  = 'pdf_template_id';
  static const _collection  = 'business_profiles';

  static PdfTemplate _selected = PdfTemplateCatalog.modern;
  static PdfTemplate get selected => _selected;

  static final ValueNotifier<int> changed = ValueNotifier(0);

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Call once at startup / after login.
  /// Reads from SQLite first (fast, offline-safe), then reconciles with
  /// Firestore in case the template changed on another device.
  static Future<void> load() async {
    // 1) Local SQLite — fast path
    try {
      final localId = await LocalDbService.instance.getSetting(_settingKey);
      if (localId != null) {
        _selected = PdfTemplateCatalog.byId(localId);
        changed.value++;
        debugPrint('[PdfTemplate] loaded from SQLite: $localId');
      }
    } catch (e) {
      debugPrint('[PdfTemplate] SQLite load failed: $e');
    }

    // 2) Firestore reconciliation — only if logged in
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .get();
      final cloudId = doc.data()?['pdfTemplate'] as String?;
      if (cloudId != null && cloudId != _selected.id) {
        _selected = PdfTemplateCatalog.byId(cloudId);
        changed.value++;
        await LocalDbService.instance.saveSetting(_settingKey, cloudId);
        debugPrint('[PdfTemplate] reconciled from Firestore: $cloudId');
      }
    } catch (e) {
      debugPrint('[PdfTemplate] Firestore load failed: $e');
    }
  }

  // ── Select ────────────────────────────────────────────────────────────────

  /// Called when the user taps "Apply template".
  static Future<void> select(PdfTemplate template) async {
    _selected = template;
    changed.value++; // update UI immediately

    // 1) Persist to SQLite
    try {
      await LocalDbService.instance.saveSetting(_settingKey, template.id);
      debugPrint('[PdfTemplate] saved to SQLite: ${template.id}');
    } catch (e) {
      debugPrint('[PdfTemplate] SQLite save failed: $e');
    }

    // 2) Sync to Firestore
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .set({'pdfTemplate': template.id}, SetOptions(merge: true));
      debugPrint('[PdfTemplate] synced to Firestore: ${template.id}');
    } catch (e) {
      debugPrint('[PdfTemplate] Firestore save failed: $e — will reconcile on next load');
    }
  }
}
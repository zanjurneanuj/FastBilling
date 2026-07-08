import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/BusinessProfile.dart';
import 'auth_service.dart';
import 'local_db_service.dart';

class ProfileService {
  ProfileService._();
  static final _fs = FirebaseFirestore.instance;
  static const _collection = 'business_profiles';

  static BusinessProfile? _cached;
  static BusinessProfile? get cached => _cached;
  static bool get hasProfile => _cached != null;

  /// Router listens to this to re-run its redirect after onboarding.
  static final ValueNotifier<int> changed = ValueNotifier(0);

  /// Load once at startup / after login: local first, then cloud fallback.
  static Future<BusinessProfile?> load([String? uid]) async {
    uid ??= AuthService.currentUser?.uid;
    if (uid == null) { _cached = null; return null; }

    var p = await LocalDbService.instance.getProfile(uid);
    if (p == null) {
      // New device, existing account -> pull from cloud and cache locally.
      try {
        final doc = await _fs.collection(_collection).doc(uid).get();
        if (doc.exists && doc.data() != null) {
          p = BusinessProfile.fromMap(doc.data()!);
          await LocalDbService.instance.saveProfile(p);
        }
      } catch (e) {
        debugPrint('[Profile] cloud fetch failed: $e');
      }
    }
    _cached = p;
    return p;
  }

  /// Called from the onboarding "Continue" button.
  static Future<BusinessProfile> save({
    required String name,
    required String address,
    String? gstNumber,
    required String currency,
    File? logoFile,
  }) async {
    final uid = AuthService.currentUser!.uid;

    String? logoPath = _cached?.logoPath;
    String? logoUrl  = _cached?.logoUrl;

    if (logoFile != null) {
      logoPath = await _saveLogoLocally(uid, logoFile);
      try {
        logoUrl = await _uploadLogo(uid, logoFile);
      } catch (e) {
        debugPrint('[Profile] logo upload failed, kept local: $e');
        // logoUrl stays null — perfectly fine, local path still works
      }
    }
    final profile = BusinessProfile(
      uid: uid, name: name, address: address,
      gstNumber: (gstNumber?.isEmpty ?? true) ? null : gstNumber,
      currency: currency, logoPath: logoPath, logoUrl: logoUrl,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await LocalDbService.instance.saveProfile(profile);       // 1) local
    await _fs.collection(_collection).doc(uid)                // 2) cloud
        .set(profile.toFirestore(), SetOptions(merge: true));

    _cached = profile;
    changed.value++;                                          // wake the router
    return profile;
  }

  static void clear() { _cached = null; changed.value++; }

  static Future<String> _saveLogoLocally(String uid, File f) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = f.path.split('.').last;
    final dest = await f.copy('${dir.path}/logo_$uid.$ext');
    return dest.path;
  }

  static Future<String> _uploadLogo(String uid, File f) async {
    final ref = FirebaseStorage.instance.ref('business_logos/$uid');
    await ref.putFile(f);
    return ref.getDownloadURL();
  }
}
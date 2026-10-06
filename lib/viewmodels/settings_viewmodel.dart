import 'package:flutter/material.dart';

import '../services/AppLockService.dart';
import '../services/auth_service.dart';
import '../services/ProfileService.dart';
import '../services/local_db_service.dart';

class SettingsViewModel extends ChangeNotifier {
  static const _cloudBackupKey = 'settings_cloud_backup';

  SettingsViewModel() {
    _restore();
  }

  Future<void> _restore() async {
    final backup = await LocalDbService.instance.getSetting(_cloudBackupKey);
    if (backup != null) cloudBackup = backup == 'true';
    notifyListeners();
  }

  // ── Read-only getters from existing services ──────────────────────────────
  // Settings doesn't own data — it reads ProfileService + ThemeProvider.
  // Add state here only when a setting needs local persistence.

  String get businessName =>
      ProfileService.cached?.name ??
          AuthService.currentUser?.displayName ??
          'You';

  String get subtitle {
    final p = ProfileService.cached;
    if (p == null) return '';
    if (p.gstNumber != null && p.gstNumber!.isNotEmpty) {
      return 'GST: ${p.gstNumber}';
    }
    return p.address;
  }

  String get currency => ProfileService.cached?.currency ?? 'INR';

  String get initials {
    final parts = businessName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return businessName.isNotEmpty ? businessName[0].toUpperCase() : '?';
  }

  // ── Toggle state ──────────────────────────────────────────────────────────
  bool cloudBackup = true;

  /// Owned by AppLockService, which actually enforces it.
  bool get appLock => AppLockService.enabled;

  void toggleCloudBackup(bool v) {
    cloudBackup = v;
    notifyListeners();
    LocalDbService.instance.saveSetting(_cloudBackupKey, v.toString());
  }

  /// Asks for fingerprint / PIN first. Returns null on success, or a
  /// message to show ('' when the user just cancelled).
  Future<String?> toggleAppLock(bool v) async {
    final err = await AppLockService.setEnabled(v);
    notifyListeners();
    return err;
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await AuthService.signOut();
    ProfileService.clear();
  }
}
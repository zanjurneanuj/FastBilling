import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../views/screens/ProfileService.dart';

class SettingsViewModel extends ChangeNotifier {
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
    return p.address ?? '';
  }

  String get currency => ProfileService.cached?.currency ?? 'INR';

  String get initials {
    final parts = businessName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return businessName.isNotEmpty ? businessName[0].toUpperCase() : '?';
  }

  // ── Toggle state ──────────────────────────────────────────────────────────
  bool cloudBackup = true;
  bool appLock     = false;

  void toggleCloudBackup(bool v) {
    cloudBackup = v;
    notifyListeners();
    // TODO: persist to local prefs
  }

  void toggleAppLock(bool v) {
    appLock = v;
    notifyListeners();
    // TODO: persist to local prefs
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await AuthService.signOut();
    ProfileService.clear();
  }
}
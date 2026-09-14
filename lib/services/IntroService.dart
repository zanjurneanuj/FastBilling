import 'local_db_service.dart';

/// Tracks whether the first-launch feature walkthrough has been shown on
/// this device. Local-only by design — it's a one-time UI courtesy, not
/// account state, so it doesn't need to sync or survive a reinstall.
class IntroService {
  IntroService._();

  static const _key = 'has_seen_intro';

  static bool hasSeenIntro = false;

  /// Call once at startup, before runApp — must complete before the
  /// router's first redirect decision so a returning user never briefly
  /// flashes the intro screen.
  static Future<void> load() async {
    final v = await LocalDbService.instance.getSetting(_key);
    hasSeenIntro = v == 'true';
  }

  static Future<void> markSeen() async {
    hasSeenIntro = true;
    await LocalDbService.instance.saveSetting(_key, 'true');
  }
}

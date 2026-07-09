import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'dart:convert' show utf8;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/UserModel.dart';
import 'local_db_service.dart';

class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(scopes: ['email']);
  static final _firestore = FirebaseFirestore.instance;

  static User?         get currentUser      => _auth.currentUser;
  static bool          get isLoggedIn       => currentUser != null;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email & Password ──────────────────────────────────────────────────────

  static Future<UserCredential> signInWithEmail(
      String email,
      String password,
      ) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _persist(cred.user);
    return cred;
  }

  static Future<UserCredential> registerWithEmail(
      String email,
      String password,
      ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _persist(cred.user);
    return cred;
  }

  static Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── Google Sign In ────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // cancelled

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await _persist(cred.user);
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    // Keep the local row so you can show "recent accounts".
    // To wipe it instead: await LocalDbService.instance.clearUsers();
  }

  // ── Local + Firestore persistence ────────────────────────────────────────

  static Future<void> _persist(User? user) async {
    if (user == null) {
      debugPrint('[Auth] _persist: user is NULL — nothing to save');
      return;
    }

    // 1) Local (sqlite/hive/whatever LocalDbService wraps) — unchanged.
    try {
      final model = UserModel.fromFirebase(user);
      debugPrint('[Auth] saving ${model.uid} / ${model.email}');
      await LocalDbService.instance.saveUser(model);
      final u = await LocalDbService.instance.getCurrentUser();
      debugPrint('[Auth] persisted user on launch: ${u?.email ?? "NONE"}');
      final check = await LocalDbService.instance.getUser(user.uid);
      debugPrint('[Auth] read-back: ${check?.email ?? "NULL — insert did not land"}');
    } catch (e, st) {
      debugPrint('[Auth] LOCAL SAVE FAILED: $e\n$st');
    }

    // 2) Firestore — profile doc + per-device login record.
    try {
      final device = await _getDeviceFingerprint();

      final userRef = _firestore.collection('users').doc(user.uid);

      // Merge profile fields so we never clobber other fields written elsewhere.
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'emailVerified': user.emailVerified,
        'providerIds': user.providerData.map((p) => p.providerId).toList(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastDevice': device,
      }, SetOptions(merge: true));

      // Keep a history of logins per device (doc id = device fingerprint hash,
      // so repeat logins from the same device update instead of piling up).
      await userRef
          .collection('devices')
          .doc(device['fingerprint'] as String)
          .set({
        ...device,
        'firstSeenAt': FieldValue.serverTimestamp(), // only sticks on create
        'lastSeenAt': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      debugPrint('[Auth] Firestore sync OK for ${user.uid}');
    } catch (e, st) {
      debugPrint('[Auth] FIRESTORE SAVE FAILED: $e\n$st');
    }
  }

  // ── Device fingerprint ───────────────────────────────────────────────────

  /// Collects non-invasive device/app details and derives a stable
  /// fingerprint hash from them. No IMEI/IMSI/MAC — those are
  /// restricted on modern Android/iOS and app-store-unsafe to collect.
  static Future<Map<String, dynamic>> _getDeviceFingerprint() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> raw = {};

    try {
      if (kIsWeb) {
        final info = await deviceInfoPlugin.webBrowserInfo;
        raw = {
          'platform': 'web',
          'browserName': info.browserName.name,
          'userAgent': info.userAgent,
          'vendor': info.vendor,
        };
      } else if (Platform.isAndroid) {
        final info = await deviceInfoPlugin.androidInfo;
        raw = {
          'platform': 'android',
          'androidId': info.id,
          'model': info.model,
          'manufacturer': info.manufacturer,
          'brand': info.brand,
          'sdkInt': info.version.sdkInt,
          'isPhysicalDevice': info.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final info = await deviceInfoPlugin.iosInfo;
        raw = {
          'platform': 'ios',
          'identifierForVendor': info.identifierForVendor,
          'model': info.utsname.machine,
          'systemName': info.systemName,
          'systemVersion': info.systemVersion,
          'isPhysicalDevice': info.isPhysicalDevice,
        };
      } else {
        raw = {'platform': Platform.operatingSystem};
      }
    } catch (e) {
      debugPrint('[Auth] device_info read failed: $e');
      raw = {'platform': kIsWeb ? 'web' : Platform.operatingSystem};
    }

    raw['appVersion'] = packageInfo.version;
    raw['buildNumber'] = packageInfo.buildNumber;
    raw['packageName'] = packageInfo.packageName;

    // Stable id to key the `devices` subcollection doc on. Built from the
    // most identity-bearing field per platform, falling back to a hash of
    // the whole map so it's still deterministic across app restarts.
    final idSeed = raw['androidId'] ??
        raw['identifierForVendor'] ??
        raw['userAgent'] ??
        raw.toString();
    raw['fingerprint'] = sha256.convert(utf8.encode(idSeed.toString())).toString();

    return raw;
  }
}
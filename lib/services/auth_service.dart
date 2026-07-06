import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/UserModel.dart';
import 'local_db_service.dart';

class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(scopes: ['email']);

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

  // ── Local persistence ─────────────────────────────────────────────────────

  static Future<void> _persist(User? user) async {
    if (user == null) {
      debugPrint('[Auth] _persist: user is NULL — nothing to save');
      return;
    }
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
  }
}
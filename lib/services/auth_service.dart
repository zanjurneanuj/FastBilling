import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  ) =>
      _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

  static Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) =>
      _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

  static Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── Google Sign In ────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Step 1: Trigger Google sign-in picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the picker
      if (googleUser == null) return null;

      // Step 2: Get auth tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Step 3: Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
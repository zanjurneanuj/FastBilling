import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthViewModel extends ChangeNotifier {
  AuthStatus _status     = AuthStatus.idle;
  String     _errorMsg   = '';
  bool       _obscurePass    = true;
  bool       _obscureConfirm = true;
  bool       _resetEmailSent = false;

  AuthStatus get status           => _status;
  String     get errorMsg         => _errorMsg;
  bool       get isLoading        => _status == AuthStatus.loading;
  bool       get obscurePassword  => _obscurePass;
  bool       get obscureConfirm   => _obscureConfirm;
  bool       get resetEmailSent   => _resetEmailSent;

  void togglePasswordVisibility() { _obscurePass    = !_obscurePass;    notifyListeners(); }
  void toggleConfirmVisibility()  { _obscureConfirm = !_obscureConfirm; notifyListeners(); }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _set(AuthStatus.loading);
    try {
      await AuthService.signInWithEmail(email, password);
      _set(AuthStatus.success);
    } catch (e) {
      _errorMsg = _friendly(e.toString());
      _set(AuthStatus.error);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _set(AuthStatus.loading);
    try {
      final cred = await AuthService.registerWithEmail(email, password);
      // Save display name to Firebase profile
      await cred.user?.updateDisplayName(name);
      _set(AuthStatus.success);
    } catch (e) {
      _errorMsg = _friendly(e.toString());
      _set(AuthStatus.error);
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    _set(AuthStatus.loading);
    try {
      final result = await AuthService.signInWithGoogle();
      if (result == null) { _set(AuthStatus.idle); return; }
      _set(AuthStatus.success);
    } catch (e) {
      _errorMsg = _friendly(e.toString());
      _set(AuthStatus.error);
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    _set(AuthStatus.loading);
    try {
      await AuthService.sendPasswordResetEmail(email);
      _resetEmailSent = true;
      _set(AuthStatus.idle);
    } catch (e) {
      _errorMsg = _friendly(e.toString());
      _set(AuthStatus.error);
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() => AuthService.signOut();

  void reset() {
    _errorMsg = '';
    _resetEmailSent = false;
    _set(AuthStatus.idle);
  }

  void _set(AuthStatus s) { _status = s; notifyListeners(); }

  String _friendly(String e) {
    if (e.contains('user-not-found'))    return 'No account found for this email.';
    if (e.contains('wrong-password'))    return 'Incorrect password.';
    if (e.contains('invalid-email'))     return 'Invalid email address.';
    if (e.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (e.contains('weak-password'))     return 'Password is too weak. Use at least 6 characters.';
    if (e.contains('network-request'))   return 'No internet connection.';
    if (e.contains('too-many-requests')) return 'Too many attempts. Please try again later.';
    return 'Something went wrong. Please try again.';
  }
}
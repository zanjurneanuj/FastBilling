import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color accent  = Color(0xFF6C63FF);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // ── Invoice status chips ─────────────────────────────────────────────────
  static const Color paid        = Color(0xFFDCFCE7);
  static const Color paidText    = Color(0xFF16A34A);
  static const Color pending     = Color(0xFFFEF9C3);
  static const Color pendingText = Color(0xFFCA8A04);
  static const Color overdue     = Color(0xFFFEE2E2);
  static const Color overdueText = Color(0xFFDC2626);

  // ── Gradient ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Light palette ─────────────────────────────────────────────────────────
  static const Color lightBackground   = Color(0xFFF5F6FA);
  static const Color lightSurface      = Color(0xFFFFFFFF);
  static const Color lightInputFill    = Color(0xFFF8F8FF);
  static const Color lightTextPrimary  = Color(0xFF111827);
  static const Color lightTextSecondary= Color(0xFF6B7280);
  static const Color lightTextHint     = Color(0xFF9CA3AF);
  static const Color lightBorder       = Color(0xFFE5E7EB);

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF0F0F14);
  static const Color darkSurface       = Color(0xFF1A1A24);
  static const Color darkInputFill     = Color(0xFF22223A);
  static const Color darkTextPrimary   = Color(0xFFF1F1F5);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextHint      = Color(0xFF6B7280);
  static const Color darkBorder        = Color(0xFF2E2E45);

  // ── Context-aware helpers ─────────────────────────────────────────────────
  static Color background(BuildContext ctx)    => _d(ctx, darkBackground,     lightBackground);
  static Color surface(BuildContext ctx)       => _d(ctx, darkSurface,        lightSurface);
  static Color inputFill(BuildContext ctx)     => _d(ctx, darkInputFill,      lightInputFill);
  static Color textPrimary(BuildContext ctx)   => _d(ctx, darkTextPrimary,    lightTextPrimary);
  static Color textSecondary(BuildContext ctx) => _d(ctx, darkTextSecondary,  lightTextSecondary);
  static Color textHint(BuildContext ctx)      => _d(ctx, darkTextHint,       lightTextHint);
  static Color border(BuildContext ctx)        => _d(ctx, darkBorder,         lightBorder);

  static Color _d(BuildContext ctx, Color dark, Color light) =>
      Theme.of(ctx).brightness == Brightness.dark ? dark : light;
}

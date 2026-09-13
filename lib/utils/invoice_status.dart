import 'package:flutter/material.dart';

/// Canonical invoice status handling, used everywhere an invoice status is
/// read from or written to Firestore.
///
/// Firestore only ever stores lowercase `'draft' | 'sent' | 'paid'`.
/// `'overdue'` is never stored — it's always derived here from `dueDate`
/// vs now for any non-paid, non-draft invoice, so a single overnight cron
/// or client-side check is never needed to keep it in sync.
class InvoiceStatus {
  InvoiceStatus._();

  static const draft = 'draft';
  static const sent = 'sent';
  static const paid = 'paid';
  static const overdue = 'overdue';

  /// Normalizes a raw Firestore `status` field (any casing) plus the
  /// invoice's due date into one of: draft, paid, sent, overdue.
  static String normalize(String? rawStatus, DateTime? dueDate,
      {DateTime? now}) {
    final raw = (rawStatus ?? sent).toLowerCase();
    if (raw == draft) return draft;
    if (raw == paid) return paid;
    final today = now ?? DateTime.now();
    if (dueDate != null && dueDate.isBefore(today)) return overdue;
    return sent;
  }

  static String label(String status) =>
      status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);

  /// Badge (background, foreground) colors for a normalized status —
  /// matches the palette already used across the app's status chips.
  static (Color bg, Color fg) badgeColors(String status) {
    switch (status.toLowerCase()) {
      case paid:
        return (const Color(0xFFE8FBF0), const Color(0xFF00B894));
      case overdue:
        return (const Color(0xFFFFECEC), const Color(0xFFEF4444));
      case sent:
        return (const Color(0xFFE8F4FF), const Color(0xFF0984E3));
      case draft:
      default:
        return (const Color(0xFFEDEDF2), const Color(0xFF6B6B76));
    }
  }
}

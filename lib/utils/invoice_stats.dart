import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_status.dart';

/// One bucket to sum invoice totals into, e.g. a day or a month.
/// [end] is exclusive.
class StatsBucket {
  final DateTime start;
  final DateTime end;
  final String label;
  const StatsBucket(this.start, this.end, this.label);
}

class TopClientTotal {
  final String name;
  final double billed;
  const TopClientTotal(this.name, this.billed);
}

class InvoiceAggregate {
  final double totalRevenue;
  final double paid;
  final double unpaid;
  final int totalInvoices;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;
  final List<double> bucketed; // parallel to the `buckets` passed in
  final List<TopClientTotal> topClients;
  final double avgDaysToPay; // 0 if no paid invoice has a paidAt timestamp

  const InvoiceAggregate({
    this.totalRevenue = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
    this.bucketed = const [],
    this.topClients = const [],
    this.avgDaysToPay = 0,
  });

  double get paidRatio => totalInvoices == 0 ? 0 : paidCount / totalInvoices;
  double get pendingRatio =>
      totalInvoices == 0 ? 0 : pendingCount / totalInvoices;
  double get overdueRatio =>
      totalInvoices == 0 ? 0 : overdueCount / totalInvoices;
}

/// Shared aggregation over a list of raw `users/{uid}/invoices` document
/// maps — used by both the Dashboard (fixed 6-month window) and Reports
/// (period-selectable window), so the "what counts as paid/overdue/revenue"
/// logic only lives in one place.
InvoiceAggregate aggregateInvoices(
  List<Map<String, dynamic>> docs, {
  required DateTime now,
  List<StatsBucket> buckets = const [],
  int topClientsLimit = 3,
}) {
  double totalRevenue = 0, paid = 0, unpaid = 0;
  int paidCount = 0, pendingCount = 0, overdueCount = 0;
  final bucketed = List<double>.filled(buckets.length, 0);
  final clientTotals = <String, double>{};
  double payDaysSum = 0;
  int payDaysCount = 0;

  for (final data in docs) {
    final rawStatus = (data['status'] as String? ?? 'sent').toLowerCase();
    if (rawStatus == InvoiceStatus.draft) continue;

    final amount = (data['grandTotal'] as num? ?? 0).toDouble();
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final status = InvoiceStatus.normalize(rawStatus, dueDate, now: now);

    totalRevenue += amount;
    if (status == InvoiceStatus.paid) {
      paid += amount;
      paidCount++;
      final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
      if (paidAt != null && createdAt != null) {
        payDaysSum += paidAt.difference(createdAt).inHours / 24.0;
        payDaysCount++;
      }
    } else {
      unpaid += amount;
      if (status == InvoiceStatus.overdue) {
        overdueCount++;
      } else {
        pendingCount++;
      }
    }

    if (createdAt != null) {
      for (var i = 0; i < buckets.length; i++) {
        final b = buckets[i];
        if (!createdAt.isBefore(b.start) && createdAt.isBefore(b.end)) {
          bucketed[i] += amount;
          break;
        }
      }
    }

    final clientName = (data['clientName'] as String?) ?? 'Client';
    clientTotals[clientName] = (clientTotals[clientName] ?? 0) + amount;
  }

  final topClients = clientTotals.entries
      .map((e) => TopClientTotal(e.key, e.value))
      .toList()
    ..sort((a, b) => b.billed.compareTo(a.billed));

  return InvoiceAggregate(
    totalRevenue: totalRevenue,
    paid: paid,
    unpaid: unpaid,
    totalInvoices: paidCount + pendingCount + overdueCount,
    paidCount: paidCount,
    pendingCount: pendingCount,
    overdueCount: overdueCount,
    bucketed: bucketed,
    topClients: topClients.take(topClientsLimit).toList(),
    avgDaysToPay: payDaysCount == 0 ? 0 : payDaysSum / payDaysCount,
  );
}

/// 6 calendar-month buckets ending with the current month, oldest first —
/// the shape the Dashboard's revenue mini-chart uses.
List<StatsBucket> lastSixMonthBuckets(DateTime now, String Function(DateTime) label) {
  final starts = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
  return List.generate(6, (i) {
    final isLast = i == 5;
    final end = isLast ? DateTime(now.year, now.month + 1) : starts[i + 1];
    return StatsBucket(starts[i], end, label(starts[i]));
  });
}

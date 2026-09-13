import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/MonthlyRevenue.dart';
import '../models/ReportsStats.dart';
import '../models/TopClient.dart';
import '../utils/invoice_stats.dart';
import '../views/screens/reports_view.dart';

class ReportsViewModel extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  ReportsStats stats = ReportsStats.empty();
  int selectedYear = DateTime.now().year;
  ReportPeriod selectedPeriod = ReportPeriod.sixMonths;

  void setPeriod(ReportPeriod period) {
    selectedPeriod = period;
    loadReports(selectedYear);
  }

  Future<void> loadReports([int? year]) async {
    isLoading = true;
    notifyListeners();

    selectedYear = year ?? DateTime.now().year;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      stats = ReportsStats.empty();
      isLoading = false;
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final range = _rangeFor(selectedPeriod, selectedYear, now);
    final previousRange = _previousRange(range);

    try {
      final invoicesRef =
      _firestore.collection('users').doc(uid).collection('invoices');

      final results = await Future.wait([
        invoicesRef
            .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
            .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
            .get(),
        invoicesRef
            .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(previousRange.start))
            .where('createdAt', isLessThan: Timestamp.fromDate(previousRange.end))
            .get(),
      ]);

      final currentDocs = results[0].docs.map((d) => d.data()).toList();
      final previousDocs = results[1].docs.map((d) => d.data()).toList();

      final buckets = _bucketsFor(selectedPeriod, range, selectedYear);
      final agg = aggregateInvoices(currentDocs,
          now: now, buckets: buckets, topClientsLimit: 3);
      final prevAgg = aggregateInvoices(previousDocs, now: now);

      final revenueChangePct = prevAgg.totalRevenue > 0
          ? (agg.totalRevenue - prevAgg.totalRevenue) / prevAgg.totalRevenue
          : (agg.totalRevenue > 0 ? 1.0 : 0.0);

      final maxBilled =
      agg.topClients.isEmpty ? 0.0 : agg.topClients.first.billed;

      stats = ReportsStats(
        totalRevenue: agg.totalRevenue,
        collected: agg.paid,
        outstanding: agg.unpaid,
        paidRatio: agg.paidRatio,
        pendingRatio: agg.pendingRatio,
        overdueRatio: agg.overdueRatio,
        revenueChangePct: revenueChangePct,
        avgPayDays: agg.avgDaysToPay,
        periodLabel: _labelFor(selectedPeriod, selectedYear),
        monthly: List.generate(
            buckets.length,
                (i) => MonthlyRevenue(
                month: buckets[i].label, amount: agg.bucketed[i])),
        topClients: agg.topClients
            .map((t) =>
            TopClient(name: t.name, billed: t.billed, maxBilled: maxBilled))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error loading reports: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadReports(selectedYear);

  String fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  // ── Period → date range ───────────────────────────────────────────────────

  ({DateTime start, DateTime end}) _rangeFor(
      ReportPeriod p, int year, DateTime now) {
    switch (p) {
      case ReportPeriod.week:
        final today = DateTime(now.year, now.month, now.day);
        return (
        start: today.subtract(const Duration(days: 6)),
        end: today.add(const Duration(days: 1)),
        );
      case ReportPeriod.month:
        return (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 1),
        );
      case ReportPeriod.year:
        return (start: DateTime(year, 1, 1), end: DateTime(year + 1, 1, 1));
      case ReportPeriod.sixMonths:
      case ReportPeriod.custom:
        // No date-range picker UI exists yet for Custom — falls back to the
        // same trailing-6-months window as the default period.
        return (
        start: DateTime(now.year, now.month - 5, 1),
        end: DateTime(now.year, now.month + 1, 1),
        );
    }
  }

  ({DateTime start, DateTime end}) _previousRange(
      ({DateTime start, DateTime end}) range) {
    final length = range.end.difference(range.start);
    return (start: range.start.subtract(length), end: range.start);
  }

  List<StatsBucket> _bucketsFor(
      ReportPeriod p, ({DateTime start, DateTime end}) range, int year) {
    switch (p) {
      case ReportPeriod.week:
        return List.generate(7, (i) {
          final day = range.start.add(Duration(days: i));
          return StatsBucket(
              day, day.add(const Duration(days: 1)), DateFormat('E').format(day));
        });
      case ReportPeriod.month:
        final dayCount = range.end.difference(range.start).inDays;
        return List.generate(dayCount, (i) {
          final day = range.start.add(Duration(days: i));
          return StatsBucket(
              day, day.add(const Duration(days: 1)), DateFormat('d').format(day));
        });
      case ReportPeriod.year:
        return List.generate(12, (i) {
          final start = DateTime(year, i + 1, 1);
          return StatsBucket(
              start, DateTime(year, i + 2, 1), DateFormat('MMM').format(start));
        });
      case ReportPeriod.sixMonths:
      case ReportPeriod.custom:
        return lastSixMonthBuckets(
            DateTime.now(), (d) => DateFormat('MMM').format(d));
    }
  }

  String _labelFor(ReportPeriod p, int year) {
    switch (p) {
      case ReportPeriod.week:
        return 'This Week';
      case ReportPeriod.month:
        return 'This Month';
      case ReportPeriod.sixMonths:
        return 'Last 6 Months';
      case ReportPeriod.year:
        return '$year';
      case ReportPeriod.custom:
        return 'Last 6 Months';
    }
  }
}

import 'package:flutter/material.dart';

import '../models/MonthlyRevenue.dart';
import '../models/ReportsStats.dart';
import '../models/TopClient.dart';




class ReportsViewModel extends ChangeNotifier {
  bool isLoading = false;
  ReportsStats stats = ReportsStats.empty();
  int selectedYear = DateTime.now().year;

  Future<void> loadReports([int? year]) async {
    isLoading = true;
    notifyListeners();

    selectedYear = year ?? DateTime.now().year;

    // ── Replace this block with your real DB/Firestore query ──────────────
    await Future.delayed(const Duration(milliseconds: 600));

    const monthly = [
      MonthlyRevenue(month: 'Jan', amount: 42000),
      MonthlyRevenue(month: 'Feb', amount: 68000),
      MonthlyRevenue(month: 'Mar', amount: 55000),
      MonthlyRevenue(month: 'Apr', amount: 78000),
      MonthlyRevenue(month: 'May', amount: 57000),
      MonthlyRevenue(month: 'Jun', amount: 176000),
    ];

    final topClients = [
      TopClient(name: 'Meridian Studio', billed: 284000, maxBilled: 284000),
      TopClient(name: 'Patel & Sons',    billed: 192200, maxBilled: 284000),
      TopClient(name: 'Lumen Design',    billed: 88000,  maxBilled: 284000),
    ];

    stats = ReportsStats(
      totalRevenue: 476000,
      collected:    342800,
      outstanding:  133200,
      paidRatio:    0.72,
      monthly:      monthly,
      topClients:   topClients,
    );
    // ─────────────────────────────────────────────────────────────────────

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadReports(selectedYear);

  String fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
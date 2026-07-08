import 'package:flutter/material.dart';

import '../services/ProfileService.dart';
import '../services/auth_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class DashboardStats {
  final double totalRevenue;
  final double paid;
  final double unpaid;
  final int totalInvoices;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;

  const DashboardStats({
    this.totalRevenue = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
  });
}

class RecentInvoice {
  final String id;
  final String number;
  final String clientName;
  final String clientInitial;
  final double amount;
  final String status; // 'paid' | 'pending' | 'overdue'
  final String date;

  const RecentInvoice({
    required this.id,
    required this.number,
    required this.clientName,
    required this.clientInitial,
    required this.amount,
    required this.status,
    required this.date,
  });
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel() {
    // ProfileService.changed fires whenever the profile is saved/edited
    // (e.g. from the Settings edit dialog) or cleared on sign-out.
    // Listening here keeps the dashboard's business name live without
    // needing a manual refresh.
    ProfileService.changed.addListener(_onProfileChanged);
  }

  bool _isLoading = false;
  String _errorMsg = '';
  DashboardStats _stats = const DashboardStats();
  List<RecentInvoice> _recentInvoices = [];

  bool                get isLoading      => _isLoading;
  String              get errorMsg       => _errorMsg;
  DashboardStats      get stats          => _stats;
  List<RecentInvoice> get recentInvoices => _recentInvoices;

  /// Always reads the live cached profile — never goes stale after an edit.
  String get businessName =>
      ProfileService.cached?.name ??
          AuthService.currentUser?.displayName ??
          'You';

  String get greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _onProfileChanged() => notifyListeners();

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMsg = '';
    notifyListeners();

    try {
      // TODO: replace with Hive / repository calls
      await Future.delayed(const Duration(milliseconds: 600));

      _stats = const DashboardStats(
        totalRevenue:  218500,
        paid:          173500,
        unpaid:         45000,
        totalInvoices:     12,
        paidCount:          8,
        pendingCount:       2,
        overdueCount:       2,
      );

      _recentInvoices = const [
        RecentInvoice(
          id: 'inv1',
          number: 'INV-2024-042',
          clientName: 'Medha Studio',
          clientInitial: 'M',
          amount: 45000,
          status: 'pending',
          date: '12 Jun 2024',
        ),
        RecentInvoice(
          id: 'inv2',
          number: 'INV-2024-041',
          clientName: 'Rohan Mehta',
          clientInitial: 'R',
          amount: 18500,
          status: 'paid',
          date: '05 Jun 2024',
        ),
        RecentInvoice(
          id: 'inv3',
          number: 'INV-2024-040',
          clientName: 'Priya Nair',
          clientInitial: 'P',
          amount: 32000,
          status: 'overdue',
          date: '20 May 2024',
        ),
        RecentInvoice(
          id: 'inv4',
          number: 'INV-2024-039',
          clientName: 'Nexus Labs',
          clientInitial: 'N',
          amount: 76000,
          status: 'paid',
          date: '10 May 2024',
        ),
      ];
    } catch (e) {
      _errorMsg = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadDashboard();

  @override
  void dispose() {
    ProfileService.changed.removeListener(_onProfileChanged);
    super.dispose();
  }
}
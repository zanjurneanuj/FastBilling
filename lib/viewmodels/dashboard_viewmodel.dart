import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  /// Total invoiced amount for each of the last 6 months, oldest first.
  final List<double> monthlyRevenue;

  const DashboardStats({
    this.totalRevenue = 0,
    this.paid = 0,
    this.unpaid = 0,
    this.totalInvoices = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
    this.monthlyRevenue = const [0, 0, 0, 0, 0, 0],
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

  final _firestore = FirebaseFirestore.instance;

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

    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _stats = const DashboardStats();
      _recentInvoices = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .orderBy('createdAt', descending: true)
          .get();

      final now = DateTime.now();
      // Bucket start for each of the last 6 months, oldest first.
      final monthStarts = List.generate(
          6, (i) => DateTime(now.year, now.month - 5 + i));

      double totalRevenue = 0, paid = 0, unpaid = 0;
      int paidCount = 0, pendingCount = 0, overdueCount = 0;
      final monthlyRevenue = List<double>.filled(6, 0);
      final recent = <RecentInvoice>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawStatus = (data['status'] as String? ?? 'sent').toLowerCase();
        if (rawStatus == 'draft') continue; // drafts aren't "sent" yet

        final amount = (data['grandTotal'] as num? ?? 0).toDouble();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final isOverdue = rawStatus != 'paid' &&
            dueDate != null &&
            dueDate.isBefore(now);

        final displayStatus =
        rawStatus == 'paid' ? 'paid' : (isOverdue ? 'overdue' : 'pending');

        totalRevenue += amount;
        if (displayStatus == 'paid') {
          paid += amount;
          paidCount++;
        } else {
          unpaid += amount;
          if (displayStatus == 'overdue') {
            overdueCount++;
          } else {
            pendingCount++;
          }
        }

        if (createdAt != null) {
          for (var i = 0; i < monthStarts.length; i++) {
            final isLastBucket = i == monthStarts.length - 1;
            final bucketEnd = isLastBucket
                ? DateTime(now.year, now.month + 1)
                : monthStarts[i + 1];
            if (!createdAt.isBefore(monthStarts[i]) &&
                createdAt.isBefore(bucketEnd)) {
              monthlyRevenue[i] += amount;
              break;
            }
          }
        }

        final clientName = (data['clientName'] as String?) ?? 'Client';

        recent.add(RecentInvoice(
          id: doc.id,
          number: (data['invoiceNumber'] as String?) ?? doc.id,
          clientName: clientName,
          clientInitial:
          clientName.trim().isNotEmpty ? clientName.trim()[0].toUpperCase() : '?',
          amount: amount,
          status: displayStatus,
          date: DateFormat('d MMM yyyy')
              .format(createdAt ?? dueDate ?? now),
        ));
      }

      _stats = DashboardStats(
        totalRevenue: totalRevenue,
        paid: paid,
        unpaid: unpaid,
        totalInvoices: paidCount + pendingCount + overdueCount,
        paidCount: paidCount,
        pendingCount: pendingCount,
        overdueCount: overdueCount,
        monthlyRevenue: monthlyRevenue,
      );

      _recentInvoices = recent.take(4).toList();
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
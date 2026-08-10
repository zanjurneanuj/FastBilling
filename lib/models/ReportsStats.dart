import 'MonthlyRevenue.dart';
import 'TopClient.dart';

class ReportsStats {
  final double totalRevenue;
  final double collected;
  final double outstanding;
  final double paidRatio;       // 0.0 – 1.0
  final double revenueChangePct;   // e.g. 0.13 for "+13% vs last period"
  final double avgPayDays;         // e.g. 6.2
  final double pendingRatio;       // e.g. 0.18
  final double overdueRatio;       // e.g. 0.10  (paidRatio + pendingRatio + overdueRatio should ≈ 1)
  final String periodLabel;        // e.g. "Jan – Jun"
  final List<MonthlyRevenue> monthly;
  final List<TopClient> topClients;

  const ReportsStats({
    required this.totalRevenue,
    required this.collected,
    required this.outstanding,
    required this.paidRatio,
    required this.monthly,
    required this.topClients,
    required this.revenueChangePct,
    required this.avgPayDays,
    required this.pendingRatio,
    required this.overdueRatio,
    required this.periodLabel
  });

  static ReportsStats empty() => const ReportsStats(
    totalRevenue: 0,
    collected: 0,
    outstanding: 0,
    paidRatio: 0,
    monthly: [],
    topClients: [], revenueChangePct: 0, avgPayDays: 0, pendingRatio: 0, overdueRatio: 0, periodLabel: '',
  );
}
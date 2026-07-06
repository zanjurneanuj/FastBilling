import 'MonthlyRevenue.dart';
import 'TopClient.dart';

class ReportsStats {
  final double totalRevenue;
  final double collected;
  final double outstanding;
  final double paidRatio;       // 0.0 – 1.0
  final List<MonthlyRevenue> monthly;
  final List<TopClient> topClients;

  const ReportsStats({
    required this.totalRevenue,
    required this.collected,
    required this.outstanding,
    required this.paidRatio,
    required this.monthly,
    required this.topClients,
  });

  static ReportsStats empty() => const ReportsStats(
    totalRevenue: 0,
    collected: 0,
    outstanding: 0,
    paidRatio: 0,
    monthly: [],
    topClients: [],
  );
}
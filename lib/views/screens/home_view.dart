import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/app_colors.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/empty_state.dart';
import '../widgets/invoice_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/stat_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          _PlaceholderTab(icon: Icons.receipt_long_outlined, label: 'Invoices'),
          _PlaceholderTab(icon: Icons.people_outline,        label: 'Clients'),
          _PlaceholderTab(icon: Icons.bar_chart_rounded,     label: 'Reports'),
          _PlaceholderTab(icon: Icons.settings_outlined,     label: 'Settings'),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 1) context.go('/invoices');
          if (i == 2) context.go('/clients');
          if (i == 3) context.go('/reports');
          if (i == 4) context.go('/settings');
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () => context.go('/invoices/create'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'Invoices',
          ),
          NavigationDestination(
            icon:         Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded, color: AppColors.primary),
            label: 'Clients',
          ),
          NavigationDestination(
            icon:         Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: 'Reports',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, vm, _) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: vm.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.surface(context),
                floating: true,
                snap: true,
                elevation: 0,
                title: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Zanvoy',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined,
                        color: AppColors.textSecondary(context)),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              vm.isLoading
                  ? const SliverFillRemaining(child: DashboardSkeleton())
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Greeting(vm: vm),
                    const SizedBox(height: 20),
                    _RevenueCard(stats: vm.stats),
                    const SizedBox(height: 16),
                    _StatsRow(stats: vm.stats),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Recent Invoices',
                      onSeeAll: () => context.go('/invoices'),
                    ),
                    const SizedBox(height: 12),
                    if (vm.recentInvoices.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No invoices yet',
                        subtitle: 'Tap + to create your first invoice.',
                        actionLabel: 'Create Invoice',
                        onAction: () => context.go('/invoices/create'),
                      )
                    else
                      ...vm.recentInvoices.map(
                            (inv) => InvoiceCard(
                          invoice: inv,
                          onTap: () => context.go('/invoices/${inv.id}/preview'),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Greeting ─────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.vm});
  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${vm.greeting},',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          vm.businessName,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Revenue Card ─────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Revenue',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_fmt(stats.totalRevenue)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MiniStat(label: 'Paid',     value: '₹${_fmt(stats.paid)}',   color: const Color(0xFF86EFAC)),
              const SizedBox(width: 24),
              _MiniStat(label: 'Unpaid',   value: '₹${_fmt(stats.unpaid)}', color: const Color(0xFFFCA5A5)),
              const SizedBox(width: 24),
              _MiniStat(label: 'Invoices', value: '${stats.totalInvoices}', color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
      ],
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StatCard(label: 'Paid',    value: '${stats.paidCount}',    icon: Icons.check_circle_outline_rounded, color: AppColors.success, subtitle: 'invoices')),
        const SizedBox(width: 10),
        Expanded(child: StatCard(label: 'Pending', value: '${stats.pendingCount}', icon: Icons.hourglass_top_rounded,        color: AppColors.warning, subtitle: 'invoices')),
        const SizedBox(width: 10),
        Expanded(child: StatCard(label: 'Overdue', value: '${stats.overdueCount}', icon: Icons.warning_amber_rounded,        color: AppColors.error,   subtitle: 'invoices')),
      ],
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String        title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See all',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// ─── Placeholder Tab ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: '$label coming soon',
      subtitle: 'This screen is being built.',
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_strings.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/empty_state.dart';
import '../widgets/invoice_card.dart';
import '../widgets/loading_skeleton.dart';
import '../screens/invoice_list_view.dart';
import '../screens/clients_view.dart';
import '../screens/reports_view.dart';
import '../screens/settings_view.dart';

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

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  // Each tab is a full screen — kept alive so state isn't lost on tab switch.
  // Not `const` (Dashboard needs the tab-switch callback below), but Flutter
  // still preserves each tab's own State across rebuilds since they keep
  // the same type/position in this list.
  List<Widget> get _tabs => [
    _DashboardTab(onNavigateTab: _goToTab),
    const InvoiceListView(),
    const ClientsView(),
    const ReportsView(),
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      // IndexedStack keeps all tabs mounted (preserves scroll/state)
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
      // FAB only on Home tab
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () => context.push('/invoices/create'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }
}

// ─── Notifications sheet ────────────────────────────────────────────────────────

void _showNotifications(
    BuildContext context, DashboardStats stats, VoidCallback onViewInvoices) {
  final items = <(IconData, Color, String, String)>[
    if (stats.overdueCount > 0)
      (
        Icons.warning_amber_rounded,
        AppColors.error,
        '${stats.overdueCount} overdue invoice${stats.overdueCount > 1 ? 's' : ''}',
        'Follow up with clients to get paid.',
      ),
    if (stats.pendingCount > 0)
      (
        Icons.hourglass_top_rounded,
        AppColors.warning,
        '${stats.pendingCount} invoice${stats.pendingCount > 1 ? 's' : ''} pending',
        'Awaiting payment from clients.',
      ),
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications',
                style: TextStyle(
                    color: AppColors.textPrimary(ctx),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text("You're all caught up.",
                    style: TextStyle(color: AppColors.textSecondary(ctx))),
              )
            else
              ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: it.$2.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(it.$1, color: it.$2, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$3,
                            style: TextStyle(
                                color: AppColors.textPrimary(ctx),
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(it.$4,
                            style: TextStyle(
                                color: AppColors.textSecondary(ctx),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              )),
            if (items.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onViewInvoices();
                  },
                  child: const Text('View invoices'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().current;
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
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon:         const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary),
            label: AppStrings.navHome(locale),
          ),
          NavigationDestination(
            icon:         const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: AppStrings.navInvoices(locale),
          ),
          NavigationDestination(
            icon:         const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people_rounded, color: AppColors.primary),
            label: AppStrings.navClients(locale),
          ),
          NavigationDestination(
            icon:         const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: AppStrings.navReports(locale),
          ),
          NavigationDestination(
            icon:         const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded, color: AppColors.primary),
            label: AppStrings.navSettings(locale),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.onNavigateTab});
  final ValueChanged<int> onNavigateTab;

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
              // ── App Bar ───────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: AppColors.surface(context),
                floating: true,
                snap: true,
                elevation: 0,
                toolbarHeight: 64,
                title: _AppBarTitle(vm: vm),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined,
                            color: AppColors.textSecondary(context), size: 24),
                        onPressed: () => _showNotifications(
                            context, vm.stats, () => onNavigateTab(1)),
                      ),
                      if (vm.stats.overdueCount > 0)
                        Positioned(
                          right: 10, top: 10,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.error, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16, left: 4),
                    child: GestureDetector(
                      onTap: () => onNavigateTab(4),
                      child: _AvatarCircle(name: vm.businessName),
                    ),
                  ),
                ],
              ),

              // ── Body ──────────────────────────────────────────────────────
              vm.isLoading
                  ? const SliverFillRemaining(child: DashboardSkeleton())
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Greeting(vm: vm),
                    const SizedBox(height: 20),
                    _RevenueCard(stats: vm.stats),
                    const SizedBox(height: 10),
                    _StatsRow(stats: vm.stats),
                    const SizedBox(height: 10),
                    _StatsRow2(stats: vm.stats),
                    const SizedBox(height: 24),
                    _QuickActions(onNavigateTab: onNavigateTab),
                    const SizedBox(height: 16),
                    if (vm.stats.overdueCount > 0) ...[
                      _OverdueBanner(
                        count: vm.stats.overdueCount,
                        onTap: () => onNavigateTab(1),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _SectionHeader(
                      title: 'Recent Invoices',
                      onSeeAll: () => onNavigateTab(1),
                    ),
                    const SizedBox(height: 12),
                    if (vm.recentInvoices.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No invoices yet',
                        subtitle: 'Tap + to create your first invoice.',
                        actionLabel: 'Create Invoice',
                        onAction: () => context.push('/invoices/create'),
                      )
                    else
                      ...vm.recentInvoices.map(
                            (inv) => InvoiceCard(
                          invoice: inv,
                          onTap: () => context
                              .push('/invoices/${inv.id}/preview'),
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

// ─── AppBar Title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.vm});
  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEE, d MMM yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(today,
            style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w400)),
        const SizedBox(height: 2),
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text('Fast Billing',
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
        ]),
      ],
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name});
  final String name;

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 34, height: 34,
    decoration: const BoxDecoration(
        color: AppColors.primary, shape: BoxShape.circle),
    child: Center(
      child: Text(_initials,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
    ),
  );
}

// ─── Greeting ─────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.vm});
  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text('${vm.greeting}, ',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 14)),
        const Text('👋', style: TextStyle(fontSize: 14)),
      ]),
      const SizedBox(height: 2),
      Text(vm.businessName,
          style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 22,
              fontWeight: FontWeight.w700)),
    ],
  );
}

// ─── Revenue Card ─────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final months = List.generate(6, (i) =>
        DateFormat('MMM').format(DateTime(now.year, now.month - 5 + i)));
    final maxMonth = stats.monthlyRevenue.fold<double>(
        0, (m, v) => v > m ? v : m);
    // Relative bar heights for the last 6 months; a flat floor keeps
    // zero-revenue months visible instead of collapsing to nothing.
    final heights = stats.monthlyRevenue
        .map((v) => maxMonth > 0 ? 0.12 + (v / maxMonth) * 0.88 : 0.12)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('Revenue this month',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Collected',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
            Text('₹${_fmt(stats.paid)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text('Pending',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
            Text('₹${_fmt(stats.unpaid)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
        ]),
        const SizedBox(height: 10),
        Text('₹${_fmt(stats.totalRevenue)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const SizedBox(height: 16),
        // Mini bar chart
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(6, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 40 * heights[i],
                  decoration: BoxDecoration(
                    color: i == 5
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            )),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: months.map((m) => Expanded(
            child: Text(m,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
          )).toList(),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─── Stats rows ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: _StatTile(
        label: 'Invoices sent',
        value: '${stats.totalInvoices}',
        sub: '${stats.pendingCount} awaiting payment',
        subColor: AppColors.textSecondary(context),
        icon: Icons.receipt_long_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.primary.withValues(alpha: 0.1),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: _StatTile(
        label: 'Paid',
        value: '${stats.paidCount}',
        sub: '₹${_fmt(stats.paid)} collected',
        subColor: AppColors.textSecondary(context),
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        iconBg: AppColors.success.withValues(alpha: 0.1),
      ),
    ),
  ]);

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _StatsRow2 extends StatelessWidget {
  const _StatsRow2({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: _StatTile(
        label: 'Outstanding',
        value: '₹${_fmt(stats.unpaid)}',
        sub: '${stats.pendingCount} invoices pending',
        subColor: AppColors.textSecondary(context),
        icon: Icons.hourglass_top_rounded,
        iconColor: AppColors.warning,
        iconBg: AppColors.warning.withValues(alpha: 0.1),
        valueColor: AppColors.warning,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: _StatTile(
        label: 'Overdue',
        value: '${stats.overdueCount}',
        sub: 'Action needed',
        subColor: AppColors.error,
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        iconBg: AppColors.error.withValues(alpha: 0.1),
        valueColor: AppColors.error,
      ),
    ),
  ]);

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.valueColor,
  });

  final String   label;
  final String   value;
  final String   sub;
  final Color    subColor;
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final Color?   valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        Container(
          width: 28, height: 28,
          decoration:
          BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 15),
        ),
      ]),
      const SizedBox(height: 8),
      Text(value,
          style: TextStyle(
              color: valueColor ?? AppColors.textPrimary(context),
              fontSize: 22,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(sub, style: TextStyle(color: subColor, fontSize: 11)),
    ]),
  );
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigateTab});
  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _QACard(
            icon: Icons.add,
            label: 'New\nInvoice',
            filled: true,
            onTap: () => context.push('/invoices/create'),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.people_outline_rounded,
            label: 'Clients',
            onTap: () => onNavigateTab(2),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.inventory_2_outlined,
            label: 'Items',
            onTap: () => context.push('/catalog'),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: () => onNavigateTab(3),
          ),
        ]),
      ],
    );
  }
}

class _QACard extends StatelessWidget {
  const _QACard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: filled
            ? [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ]
            : null,
      ),
      child: Material(
        color: filled ? AppColors.primary : AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled
                  ? null
                  : Border.all(color: AppColors.border(context)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 22,
                  color: filled ? Colors.white : AppColors.primary),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: filled
                          ? Colors.white
                          : AppColors.textPrimary(context))),
            ]),
          ),
        ),
      ),
    ),
  );
}

// ─── Overdue Banner ───────────────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.error.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count overdue invoice${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 1),
                  Text('Action needed',
                      style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.7),
                          fontSize: 11)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('View',
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w600)),
      if (onSeeAll != null)
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text('See all',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ),
    ],
  );
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/locale_provider.dart';
import '../../services/NotificationService.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_strings.dart';
import '../../utils/invoice_gate.dart';
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
        onPressed: () => openNewInvoice(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }
}

/// Opens the invoice list pre-filtered, e.g. from a dashboard tile.
void _openInvoices(BuildContext context, String filter) =>
    context.push('/invoices?filter=$filter');

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
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                toolbarHeight: 68,
                titleSpacing: 16,
                automaticallyImplyLeading: false,
                title: _AppBarTitle(
                  vm: vm,
                  onAvatarTap: () => onNavigateTab(4),
                ),
                actions: [
                  const _NotificationBell(),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: AppColors.border(context)),
                ),
              ),

              // ── Quick actions — always first, even while loading ──────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickActions(onNavigateTab: onNavigateTab),
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              vm.isLoading
                  ? const SliverFillRemaining(child: DashboardSkeleton())
                  : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (vm.stats.overdueCount > 0) ...[
                      _OverdueBanner(
                        count: vm.stats.overdueCount,
                        onTap: () => _openInvoices(context, 'overdue'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _RevenueCard(stats: vm.stats),
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Overview'),
                    const SizedBox(height: 12),
                    _StatsGrid(stats: vm.stats),
                    const SizedBox(height: 24),
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
                        onAction: () => openNewInvoice(context),
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
  const _AppBarTitle({required this.vm, required this.onAvatarTap});
  final DashboardViewModel vm;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEE, d MMM').format(DateTime.now());
    return Row(children: [
      GestureDetector(
        onTap: onAvatarTap,
        child: _AvatarCircle(name: vm.businessName),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${vm.greeting} 👋 · $today',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(vm.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ],
        ),
      ),
    ]);
  }
}

// ─── Notification bell ────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.changed,
      builder: (context, _, _) {
        final unread = NotificationService.unreadCount;
        return Material(
          color: AppColors.background(context),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/notifications'),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(clipBehavior: Clip.none, children: [
                Center(
                  child: Icon(
                      unread > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      color: AppColors.textPrimary(context),
                      size: 23),
                ),
                if (unread > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface(context), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1)),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
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
    width: 42, height: 42,
    decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(13)),
    child: Center(
      child: Text(_initials,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700)),
    ),
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

// ─── Overview grid ────────────────────────────────────────────────────────────

String _fmtAmount(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

/// The four headline numbers. Each tile opens the invoice list filtered to
/// exactly the invoices it counts.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final unpaidCount = stats.pendingCount + stats.overdueCount;
    final tiles = [
      _StatTile(
        label: 'Invoices sent',
        value: '${stats.totalInvoices}',
        sub: '$unpaidCount awaiting payment',
        icon: Icons.send_rounded,
        color: AppColors.primary,
        onTap: () => _openInvoices(context, 'sent'),
      ),
      _StatTile(
        label: 'Paid',
        value: '${stats.paidCount}',
        sub: '₹${_fmtAmount(stats.paid)} collected',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        onTap: () => _openInvoices(context, 'paid'),
      ),
      _StatTile(
        label: 'Outstanding',
        value: '₹${_fmtAmount(stats.unpaid)}',
        sub: '$unpaidCount unpaid invoice${unpaidCount == 1 ? '' : 's'}',
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        highlightValue: true,
        onTap: () => _openInvoices(context, 'outstanding'),
      ),
      _StatTile(
        label: 'Overdue',
        value: '${stats.overdueCount}',
        sub: stats.overdueCount == 0 ? 'All on time' : 'Action needed',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        highlightValue: stats.overdueCount > 0,
        onTap: () => _openInvoices(context, 'overdue'),
      ),
    ];

    return Column(children: [
      Row(children: [
        Expanded(child: tiles[0]),
        const SizedBox(width: 10),
        Expanded(child: tiles[1]),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: tiles[2]),
        const SizedBox(width: 10),
        Expanded(child: tiles[3]),
      ]),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
    this.highlightValue = false,
  });

  final String       label;
  final String       value;
  final String       sub;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         highlightValue;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface(context),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.textHint(context)),
          ]),
          const SizedBox(height: 12),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: highlightValue ? color : AppColors.textPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11.5)),
        ]),
      ),
    ),
  );
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

/// Pinned to the top of the dashboard: the things people do every day.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigateTab});
  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary action — full width, impossible to miss.
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: InkWell(
              onTap: () => openNewInvoice(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create new invoice',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('GST-ready PDF in under a minute',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _QACard(
            icon: Icons.people_outline_rounded,
            label: 'Clients',
            color: const Color(0xFF0EA5E9),
            onTap: () => onNavigateTab(2),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.inventory_2_outlined,
            label: 'Items',
            color: const Color(0xFFF59E0B),
            onTap: () => context.push('/catalog'),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.receipt_long_outlined,
            label: 'Invoices',
            color: AppColors.primary,
            onTap: () => onNavigateTab(1),
          ),
          const SizedBox(width: 10),
          _QACard(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            color: AppColors.success,
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
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context))),
          ]),
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
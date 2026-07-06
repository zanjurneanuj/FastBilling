import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/TopClient.dart';
import '../../utils/app_colors.dart';
import '../../viewmodels/reports_viewmodel.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with AutomaticKeepAliveClientMixin {
  // Keep alive so state isn't lost when switching tabs in IndexedStack
  @override
  bool get wantKeepAlive => true;

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load once — safe here because context is fully mounted
    if (!_loaded) {
      _loaded = true;
      context.read<ReportsViewModel>().loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return Consumer<ReportsViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: vm.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
                      child: Row(children: [
                        Text('Reports',
                            style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 26,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        _YearPicker(
                          year: vm.selectedYear,
                          onChanged: (y) => vm.loadReports(y),
                        ),
                      ]),
                    ),
                  ),

                  if (vm.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _RevenueChartCard(vm: vm),
                          const SizedBox(height: 14),
                          _SummaryRow(vm: vm),
                          const SizedBox(height: 24),
                          Text('Top clients',
                              style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                          if (vm.stats.topClients.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('No client data yet.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 13)),
                            )
                          else
                            ...vm.stats.topClients
                                .map((c) => _TopClientRow(client: c, vm: vm)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Year Picker ──────────────────────────────────────────────────────────────

class _YearPicker extends StatelessWidget {
  const _YearPicker({required this.year, required this.onChanged});
  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final years = List.generate(5, (i) => DateTime.now().year - i);
    return PopupMenuButton<int>(
      initialValue: year,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$year',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary, size: 18),
        ]),
      ),
      itemBuilder: (_) => years
          .map((y) => PopupMenuItem(
        value: y,
        child: Text('$y',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: y == year
                    ? FontWeight.w700
                    : FontWeight.w400)),
      ))
          .toList(),
    );
  }
}

// ─── Revenue Chart Card ───────────────────────────────────────────────────────

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.vm});
  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final monthly = vm.stats.monthly;
    final maxAmt =
    monthly.isEmpty ? 1.0 : monthly.map((m) => m.amount).reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue · last 6 months',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 13)),
        const SizedBox(height: 6),
        Text('₹${vm.fmt(vm.stats.totalRevenue)}',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const SizedBox(height: 20),

        // ── Bars ────────────────────────────────────────────────────
        SizedBox(
          height: 120,
          child: monthly.isEmpty
              ? Center(
              child: Text('No data',
                  style: TextStyle(
                      color: AppColors.textHint(context), fontSize: 13)))
              : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: monthly.map((m) {
              final ratio = maxAmt > 0 ? m.amount / maxAmt : 0.0;
              final isMax = m.amount == maxAmt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: math.max(4, 80 * ratio),
                        decoration: BoxDecoration(
                          color: isMax
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(m.month,
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 11)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────
// Fixed: removed Expanded inside unbounded Column — use fixed heights instead

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.vm});
  final ReportsViewModel vm;

  // Fixed height for the two stacked tiles
  static const double _tileH = 80;
  static const double _gap   = 12;
  static const double _totalH = _tileH * 2 + _gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _totalH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Donut ────────────────────────────────────────────────
          Container(
            width: 155,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _DonutPainter(
                      ratio: vm.stats.paidRatio,
                      paidColor: AppColors.primary,
                      dueColor: const Color(0xFFF6C90E),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(vm.stats.paidRatio * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                          Text('paid',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _LegendDot(color: AppColors.primary, label: 'Paid'),
                  const SizedBox(width: 10),
                  _LegendDot(
                      color: const Color(0xFFF6C90E), label: 'Due'),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Collected + Outstanding ──────────────────────────────
          Expanded(
            child: Column(
              children: [
                _StatTile2(
                  height: _tileH,
                  label: 'Collected',
                  value: '₹${vm.fmt(vm.stats.collected)}',
                  valueColor: AppColors.textPrimary(context),
                ),
                const SizedBox(height: _gap),
                _StatTile2(
                  height: _tileH,
                  label: 'Outstanding',
                  value: '₹${vm.fmt(vm.stats.outstanding)}',
                  valueColor: AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 7, height: 7,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: AppColors.textSecondary(context), fontSize: 10)),
    ],
  );
}

// Fixed: takes explicit height, no Expanded
class _StatTile2 extends StatelessWidget {
  const _StatTile2({
    required this.height,
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final double height;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

// ─── Top Client Row ───────────────────────────────────────────────────────────

class _TopClientRow extends StatelessWidget {
  const _TopClientRow({required this.client, required this.vm});
  final TopClient client;
  final ReportsViewModel vm;

  static const _palettes = [
    (bg: Color(0xFFE8E4FF), fg: Color(0xFF6C5CE7)),
    (bg: Color(0xFFFFE8E8), fg: Color(0xFFE17055)),
    (bg: Color(0xFFE8FFE8), fg: Color(0xFF00B894)),
    (bg: Color(0xFFFFF3E0), fg: Color(0xFFF39C12)),
    (bg: Color(0xFFE0F4FF), fg: Color(0xFF0984E3)),
  ];

  String get _initials {
    final parts = client.name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return client.name.isNotEmpty ? client.name[0].toUpperCase() : '?';
  }

  ({Color bg, Color fg}) get _color {
    final idx =
        client.name.codeUnits.fold(0, (a, b) => a + b) % _palettes.length;
    return _palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: c.bg, borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(_initials,
                style: TextStyle(
                    color: c.fg, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(client.name,
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Text('₹${vm.fmt(client.billed)}',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: client.ratio,
                minHeight: 5,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Donut Painter ────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.ratio,
    required this.paidColor,
    required this.dueColor,
  });
  final double ratio;
  final Color paidColor;
  final Color dueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    const strokeW = 13.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color       = dueColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap   = StrokeCap.round,
    );
    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi * ratio, false,
      Paint()
        ..color       = paidColor
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.ratio != ratio;
}
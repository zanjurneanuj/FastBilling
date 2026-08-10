import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/TopClient.dart';
import '../../providers/theme_provider.dart'; // adjust import path if needed
import '../../viewmodels/reports_viewmodel.dart';

enum ReportPeriod { week, month, sixMonths, year, custom }


// ─── Theme-aware color palette ─────────────────────────────────────────────────

class _RC {
  final Color bg;
  final Color card;
  final Color cardBorder;
  final Color purple;
  final Color green;
  final Color orange;
  final Color red;
  final Color textDim;
  final Color textPrimary;
  final Color iconDim;
  final Color chipBg;
  final Color progressTrack;

  const _RC({
    required this.bg,
    required this.card,
    required this.cardBorder,
    required this.purple,
    required this.green,
    required this.orange,
    required this.red,
    required this.textDim,
    required this.textPrimary,
    required this.iconDim,
    required this.chipBg,
    required this.progressTrack,
  });

  factory _RC.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _RC(
        bg:           Color(0xFF14122A),
        card:         Color(0xFF1E1B3A),
        cardBorder:   Color(0xFF2C2853),
        purple:       Color(0xFF8B7CFF),
        green:        Color(0xFF3ECF8E),
        orange:       Color(0xFFF5A623),
        red:          Color(0xFFFF6B6B),
        textDim:      Color(0xFF9490B8),
        textPrimary:  Colors.white,
        iconDim:      Color(0xFF9490B8),
        chipBg:       Color(0x0FFFFFFF),  // white ~6%
        progressTrack:Color(0x14FFFFFF),  // white ~8%
      );
    } else {
      return const _RC(
        bg:           Color(0xFFF2F1FA),
        card:         Colors.white,
        cardBorder:   Color(0xFFE2DEFF),
        purple:       Color(0xFF7B6CF6),
        green:        Color(0xFF27AE74),
        orange:       Color(0xFFE09400),
        red:          Color(0xFFE05252),
        textDim:      Color(0xFF7B789A),
        textPrimary:  Color(0xFF1A1830),
        iconDim:      Color(0xFF9490B8),
        chipBg:       Color(0x0F7B6CF6),  // purple ~6%
        progressTrack:Color(0x1A7B6CF6),  // purple ~10%
      );
    }
  }
}

// ─── Main View ─────────────────────────────────────────────────────────────────

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<ReportsViewModel>().loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Subscribe to ThemeProvider so this widget rebuilds on theme toggle
    context.watch<ThemeProvider>();

    // Build the reactive color palette from current theme
    final c = _RC.of(context);

    return Consumer<ReportsViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: RefreshIndicator(
              color: c.purple,
              backgroundColor: c.card,
              onRefresh: vm.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Row(children: [
                        Text(
                          'Analytics',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _PeriodRangePill(
                          label: vm.stats.periodLabel,
                          c: c,
                        ),
                      ]),
                    ),
                  ),

                  // ── Period selector ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: _PeriodSelector(
                      selected: vm.selectedPeriod,
                      onChanged: vm.setPeriod,
                      c: c,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  if (vm.isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: c.purple),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _RevenueChartCard(vm: vm, c: c),
                          const SizedBox(height: 14),
                          _SummaryRow(vm: vm, c: c),
                          const SizedBox(height: 24),
                          Row(children: [
                            Text(
                              'Top clients',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'See all',
                                style: TextStyle(
                                  color: c.purple,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          if (vm.stats.topClients.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'No client data yet.',
                                style: TextStyle(color: c.textDim, fontSize: 13),
                              ),
                            )
                          else
                            ...vm.stats.topClients
                                .map((cl) => _TopClientRow(client: cl, vm: vm, c: c)),
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

// ─── Period range pill ─────────────────────────────────────────────────────────

class _PeriodRangePill extends StatelessWidget {
  const _PeriodRangePill({required this.label, required this.c});
  final String label;
  final _RC c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: c.chipBg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_today_rounded, color: c.iconDim, size: 13),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]),
  );
}

// ─── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
    required this.c,
  });
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;
  final _RC c;

  static const _options = [
    (ReportPeriod.week,       'Week'),
    (ReportPeriod.month,      'Month'),
    (ReportPeriod.sixMonths,  '6 Months'),
    (ReportPeriod.year,       'Year'),
    (ReportPeriod.custom,     'Custom'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _options.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final opt = _options[i];
        final isSelected = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onChanged(opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? c.purple : c.chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                color: isSelected ? Colors.white : c.textDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─── Revenue chart card ────────────────────────────────────────────────────────

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.vm, required this.c});
  final ReportsViewModel vm;
  final _RC c;

  @override
  Widget build(BuildContext context) {
    final monthly = vm.stats.monthly;
    final maxAmt =
    monthly.isEmpty ? 1.0 : monthly.map((m) => m.amount as double).reduce(math.max);
    final isPositive = vm.stats.revenueChangePct >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Revenue · ${vm.stats.periodLabel.toLowerCase()}',
              style: TextStyle(color: c.textDim, fontSize: 13),
            ),
          ),
          _IconChip(icon: Icons.ios_share_rounded, c: c),
          const SizedBox(width: 8),
          _IconChip(icon: Icons.download_rounded, c: c),
        ]),
        const SizedBox(height: 8),
        Text(
          '₹${vm.fmt(vm.stats.totalRevenue)}',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isPositive ? c.green : c.red).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 11,
                color: isPositive ? c.green : c.red,
              ),
              const SizedBox(width: 2),
              Text(
                '${(vm.stats.revenueChangePct.abs() * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: isPositive ? c.green : c.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            'vs last period',
            style: TextStyle(color: c.textDim, fontSize: 11),
          ),
        ]),
        const SizedBox(height: 20),

        SizedBox(
          height: 130,
          child: monthly.isEmpty
              ? Center(
            child: Text(
              'No data',
              style: TextStyle(color: c.textDim, fontSize: 13),
            ),
          )
              : _LineChart(
            monthly: monthly,
            maxAmt: maxAmt,
            fmt: vm.fmt,
            c: c,
          ),
        ),
      ]),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.c});
  final IconData icon;
  final _RC c;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: c.chipBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: c.iconDim, size: 14),
  );
}

// ─── Line chart ────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.monthly,
    required this.maxAmt,
    required this.fmt,
    required this.c,
  });
  final List<dynamic> monthly;
  final double maxAmt;
  final String Function(double) fmt;
  final _RC c;

  @override
  Widget build(BuildContext context) {
    final maxIdx = monthly.indexWhere((m) => m.amount == maxAmt);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LineChartPainter(
              values: monthly.map<double>((m) => m.amount as double).toList(),
              maxAmt: maxAmt,
              lineColor: c.purple,
            ),
          ),
        ),
        // Tooltip bubble over peak
        if (maxIdx != -1)
          LayoutBuilder(builder: (context, constraints) {
            final chartH = constraints.maxHeight - 22;
            final stepX = constraints.maxWidth / (monthly.length - 1);
            final x = stepX * maxIdx;
            final ratio = maxAmt > 0 ? monthly[maxIdx].amount / maxAmt : 0.0;
            final y = chartH - (chartH * ratio);
            return Positioned(
              left: (x - 34).clamp(0, constraints.maxWidth - 68),
              top: (y - 34).clamp(0.0, double.infinity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.textPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${monthly[maxIdx].month}: ₹${fmt(monthly[maxIdx].amount as double)}',
                  style: TextStyle(
                    color: c.bg,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        // Month labels
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Row(
            children: monthly
                .map<Widget>((m) => Expanded(
              child: Text(
                m.month as String,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textDim, fontSize: 10),
              ),
            ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.maxAmt,
    required this.lineColor,
  });
  final List<double> values;
  final double maxAmt;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final chartH = size.height - 22;
    final stepX =
    values.length > 1 ? size.width / (values.length - 1) : size.width;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final ratio = maxAmt > 0 ? values[i] / maxAmt : 0.0;
      points.add(Offset(stepX * i, chartH - (chartH * ratio)));
    }

    // Gradient fill
    final fillPath = Path()..moveTo(points.first.dx, chartH);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath..lineTo(points.last.dx, chartH)..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.28), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Dots — draw bg circle first to "cut" the line visually
    for (final p in points) {
      canvas.drawCircle(p, 4,
          Paint()..color = lineColor.withOpacity(0.15)); // subtle glow
      canvas.drawCircle(
          p, 4,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.maxAmt != maxAmt || old.lineColor != lineColor;
}

// ─── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.vm, required this.c});
  final ReportsViewModel vm;
  final _RC c;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Collected',
                value: '₹${vm.fmt(vm.stats.collected)}',
                valueColor: c.green,
                c: c,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _StatTile(
                label: 'Outstanding',
                value: '₹${vm.fmt(vm.stats.outstanding)}',
                valueColor: c.orange,
                c: c,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _StatTile(
                label: 'Avg pay period',
                value: '${vm.stats.avgPayDays.toStringAsFixed(1)}d',
                valueColor: c.textPrimary,
                c: c,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Donut card ───────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.cardBorder),
          ),
          child: Row(children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _DonutPainter(
                  paidRatio:    vm.stats.paidRatio,
                  pendingRatio: vm.stats.pendingRatio,
                  overdueRatio: vm.stats.overdueRatio,
                  paidColor:    c.purple,
                  pendingColor: c.orange,
                  overdueColor: c.red,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(vm.stats.paidRatio * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Paid',
                        style: TextStyle(color: c.textDim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(color: c.purple, label: 'Paid',    pct: vm.stats.paidRatio,    c: c),
                  const SizedBox(height: 10),
                  _LegendRow(color: c.orange, label: 'Pending', pct: vm.stats.pendingRatio, c: c),
                  const SizedBox(height: 10),
                  _LegendRow(color: c.red,    label: 'Overdue', pct: vm.stats.overdueRatio, c: c),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.c,
  });
  final String label;
  final String value;
  final Color valueColor;
  final _RC c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textDim,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.pct,
    required this.c,
  });
  final Color color;
  final String label;
  final double pct;
  final _RC c;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        label,
        style: TextStyle(color: c.textDim, fontSize: 13),
      ),
    ),
    Text(
      '${(pct * 100).toStringAsFixed(0)}%',
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  ]);
}

// ─── Donut painter ─────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.paidRatio,
    required this.pendingRatio,
    required this.overdueRatio,
    required this.paidColor,
    required this.pendingColor,
    required this.overdueColor,
  });
  final double paidRatio;
  final double pendingRatio;
  final double overdueRatio;
  final Color paidColor;
  final Color pendingColor;
  final Color overdueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 7;
    const strokeW = 11.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    double start = -math.pi / 2;
    for (final seg in [
      (paidRatio,    paidColor),
      (pendingRatio, pendingColor),
      (overdueRatio, overdueColor),
    ]) {
      final sweep = 2 * math.pi * seg.$1;
      canvas.drawArc(
        rect, start, sweep, false,
        Paint()
          ..color = seg.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.paidRatio != paidRatio ||
          old.pendingRatio != pendingRatio ||
          old.overdueRatio != overdueRatio ||
          old.paidColor != paidColor ||
          old.pendingColor != pendingColor ||
          old.overdueColor != overdueColor;
}

// ─── Top client row ────────────────────────────────────────────────────────────

class _TopClientRow extends StatelessWidget {
  const _TopClientRow({required this.client, required this.vm, required this.c});
  final TopClient client;
  final ReportsViewModel vm;
  final _RC c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              client.name,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '₹${vm.fmt(client.billed)}',
            style: TextStyle(
              color: c.purple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: client.ratio,
            minHeight: 6,
            backgroundColor: c.progressTrack,
            valueColor: AlwaysStoppedAnimation(c.purple),
          ),
        ),
      ]),
    );
  }
}
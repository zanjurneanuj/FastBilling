import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double  height;
  final double  radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: 8),
          const SkeletonBox(width: 100, height: 14),
          const SizedBox(height: 24),
          const SkeletonBox(height: 130, radius: 16),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 120, height: 16),
          const SizedBox(height: 12),
          const SkeletonBox(height: 64, radius: 12),
          const SizedBox(height: 10),
          const SkeletonBox(height: 64, radius: 12),
          const SizedBox(height: 10),
          const SkeletonBox(height: 64, radius: 12),
        ],
      ),
    );
  }
}
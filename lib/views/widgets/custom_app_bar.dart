import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class ZanvoyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZanvoyAppBar({
    super.key,
    this.title,
    this.actions,
    this.showLogo = false,
    this.bottom,
  });

  final String?            title;
  final List<Widget>?      actions;
  final bool               showLogo;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface(context),
      elevation: 0,
      bottom: bottom,
      title: showLogo
          ? Row(
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
      )
          : Text(
        title ?? '',
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      actions: actions,
      iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
    );
  }
}
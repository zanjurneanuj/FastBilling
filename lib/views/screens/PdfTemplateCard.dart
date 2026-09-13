import 'package:flutter/material.dart';

import '../../models/PdfTemplate.dart';
import '../../utils/app_colors.dart';

/// A single selectable template card: mini invoice mockup + name/description,
/// with an "Active" badge and highlighted border when selected.
class PdfTemplateCard extends StatelessWidget {
  const PdfTemplateCard({
    super.key,
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final PdfTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _MiniInvoicePreview(template: template),
                if (isSelected)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 11, color: Colors.white),
                          SizedBox(width: 2),
                          Text('Active',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(template.name,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(template.description,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// A color-only swatch — not a fake invoice mockup. Real layout/content can
/// only be seen in the actual generated PDF (Settings > PDF template opens
/// a live preview of the real thing), so this card doesn't pretend to
/// render invoice text it isn't actually laying out.
class _MiniInvoicePreview extends StatelessWidget {
  const _MiniInvoicePreview({required this.template});
  final PdfTemplate template;

  @override
  Widget build(BuildContext context) {
    final textColor = template.darkHeader ? Colors.white : Colors.black87;

    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: template.headerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: template.accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text('INVOICE',
              style: TextStyle(
                  color: textColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}
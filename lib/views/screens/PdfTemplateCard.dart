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
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INVOICE',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: template.accentColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          for (final w in [1.0, 0.7, 0.5]) ...[
            Container(
              margin: const EdgeInsets.only(top: 3),
              height: 3,
              width: 60 * w,
              decoration: BoxDecoration(
                color: (template.darkHeader ? Colors.white : Colors.black)
                    .withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
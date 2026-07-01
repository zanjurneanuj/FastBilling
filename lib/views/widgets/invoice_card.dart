import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice, this.onTap});

  final RecentInvoice invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (chipBg, chipTxt) = switch (invoice.status) {
      'paid'    => (AppColors.paid,    AppColors.paidText),
      'overdue' => (AppColors.overdue, AppColors.overdueText),
      _         => (AppColors.pending, AppColors.pendingText),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            // Client avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  invoice.clientInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Client + invoice number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clientName,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invoice.number,
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Amount + status chip
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_fmt(invoice.amount)}',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label(invoice.status),
                    style: TextStyle(
                      color: chipTxt,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L'
          : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k'
          : v.toStringAsFixed(0);

  String _label(String s) => s[0].toUpperCase() + s.substring(1);
}
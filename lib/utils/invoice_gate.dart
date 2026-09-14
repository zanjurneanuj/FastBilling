import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/SubscriptionService.dart';

/// Central entry point for "create a new invoice". Every "+ New invoice"
/// affordance in the app should call this instead of pushing
/// '/invoices/create' directly, so the free-invoice paywall is enforced
/// consistently everywhere. Editing an existing invoice never goes
/// through here — only brand-new ones count against the free limit.
void openNewInvoice(BuildContext context) {
  if (SubscriptionService.canCreateInvoice) {
    context.push('/invoices/create');
  } else {
    context.push('/upgrade');
  }
}

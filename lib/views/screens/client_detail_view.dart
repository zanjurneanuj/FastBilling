import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ClientItem.dart';
import '../../models/InvoiceListItem.dart';
import '../../utils/app_colors.dart';
import '../../utils/invoice_status.dart';
import '../../viewmodels/client_viewmodel.dart';
import '../widgets/client_avatar.dart';
import '../widgets/empty_state.dart';

class ClientDetailView extends StatefulWidget {
  const ClientDetailView({super.key, required this.clientId});
  final String clientId;

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> {
  bool _loading = true;
  ClientItem? _client;
  List<InvoiceListItem> _invoices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final client = await context.read<ClientsViewModel>().getClient(widget.clientId);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    var invoices = <InvoiceListItem>[];
    if (uid != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .where('clientId', isEqualTo: widget.clientId)
          .get();

      final now = DateTime.now();
      invoices = snapshot.docs.map((doc) {
        final data = doc.data();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return InvoiceListItem(
          id: doc.id,
          clientId: widget.clientId,
          clientName: (data['clientName'] as String?) ?? '',
          invoiceNumber: (data['invoiceNumber'] as String?) ?? doc.id,
          dateLabel: DateFormat('d MMM').format(createdAt ?? dueDate ?? now),
          amount: (data['grandTotal'] as num? ?? 0).toDouble(),
          status: InvoiceStatus.normalize(
              data['status'] as String?, dueDate, now: now),
          createdAt: createdAt,
        );
      }).toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }

    if (!mounted) return;
    setState(() {
      _client = client;
      _invoices = invoices;
      _loading = false;
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/clients');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary(context)),
          onPressed: _goBack,
        ),
        title: Text('Client',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary))
          : _client == null
          ? EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Client not found',
        subtitle: 'This client may have been deleted.',
        actionLabel: 'Back to clients',
        onAction: () => context.go('/clients'),
      )
          : RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Row(children: [
              ClientAvatar(name: _client!.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_client!.name,
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(_client!.email,
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13)),
                      if (_client!.phone.isNotEmpty)
                        Text(_client!.phone,
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 13)),
                    ]),
              ),
            ]),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total billed',
                    style: TextStyle(
                        color: AppColors.textSecondary(context), fontSize: 12)),
                const SizedBox(height: 4),
                Text('₹${_fmt(_client!.totalBilled)}',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Invoices',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_invoices.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No invoices yet',
                subtitle: 'Invoices billed to this client will show up here.',
              )
            else
              ..._invoices.map((inv) => _InvoiceTile(
                invoice: inv,
                onTap: () => context.go('/invoices/${inv.id}/preview'),
              )),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.onTap});
  final InvoiceListItem invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = InvoiceStatus.badgeColors(invoice.status);
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
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.invoiceNumber,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(invoice.dateLabel,
                      style: TextStyle(
                          color: AppColors.textSecondary(context), fontSize: 12)),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${invoice.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(InvoiceStatus.label(invoice.status),
                  style: TextStyle(
                      color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

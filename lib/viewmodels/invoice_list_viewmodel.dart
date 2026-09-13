import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/InvoiceListItem.dart';
import '../utils/invoice_status.dart';

enum InvoiceSort { newest, oldest, amountAsc, amountDesc }

class InvoiceListViewModel extends ChangeNotifier {
  List<InvoiceListItem> invoices = [];
  bool isLoading = false;
  String? errorMessage;

  String selectedFilter = 'All';
  String searchQuery = '';
  InvoiceSort sort = InvoiceSort.newest;

  static const List<String> filters = [
    'All',
    'Draft',
    'Sent',
    'Paid',
    'Overdue',
  ];

  Future<void> loadInvoices() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      invoices = [];
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('invoices')
          .orderBy('createdAt', descending: true)
          .get();

      final now = DateTime.now();
      invoices = snapshot.docs.map((doc) {
        final data = doc.data();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final status = InvoiceStatus.normalize(
            data['status'] as String?, dueDate, now: now);

        return InvoiceListItem(
          id: doc.id,
          clientId: data['clientId'] as String?,
          clientName: (data['clientName'] as String?) ?? 'Client',
          invoiceNumber: (data['invoiceNumber'] as String?) ?? doc.id,
          dateLabel:
          DateFormat('d MMM').format(createdAt ?? dueDate ?? now),
          amount: (data['grandTotal'] as num? ?? 0).toDouble(),
          status: status,
          createdAt: createdAt,
        );
      }).toList();
    } catch (e) {
      errorMessage = 'Could not load invoices. Please try again.';
    }

    isLoading = false;
    notifyListeners();
  }

  void setFilter(String filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void setSort(InvoiceSort s) {
    sort = s;
    notifyListeners();
  }

  List<InvoiceListItem> get filteredInvoices {
    final query = searchQuery.trim().toLowerCase();
    var list = invoices.where((invoice) {
      final matchesFilter =
          selectedFilter == 'All' || invoice.status == selectedFilter.toLowerCase();
      final matchesSearch = query.isEmpty ||
          invoice.clientName.toLowerCase().contains(query) ||
          invoice.invoiceNumber.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();

    switch (sort) {
      case InvoiceSort.newest:
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        break;
      case InvoiceSort.oldest:
        list.sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));
        break;
      case InvoiceSort.amountAsc:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case InvoiceSort.amountDesc:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
    }
    return list;
  }
}

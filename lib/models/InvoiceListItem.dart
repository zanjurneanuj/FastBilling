import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// MODEL
/// ---------------------------------------------------------------------
class InvoiceListItem {
  final String id;
  final String clientName;
  final String invoiceNumber; // 'INV-2026-014'
  final String dateLabel; // '12 Jun'
  final double amount;
  final String status; // 'Paid' | 'Sent' | 'Draft' | 'Overdue'

  const InvoiceListItem({
    required this.id,
    required this.clientName,
    required this.invoiceNumber,
    required this.dateLabel,
    required this.amount,
    required this.status,
  });
}

/// ---------------------------------------------------------------------
/// STATUS STYLING (derived from InvoiceListItem.status string)
/// ---------------------------------------------------------------------
class _StatusStyle {
  final Color bg;
  final Color text;
  const _StatusStyle(this.bg, this.text);
}

_StatusStyle _styleForStatus(String status) {
  switch (status) {
    case 'Draft':
      return const _StatusStyle(Color(0xFFEDEDF2), Color(0xFF6B6B76));
    case 'Sent':
      return const _StatusStyle(Color(0xFFDCE7FE), Color(0xFF3457D5));
    case 'Paid':
      return const _StatusStyle(Color(0xFFD9F2E3), Color(0xFF1E9E5A));
    case 'Overdue':
      return const _StatusStyle(Color(0xFFFBDADA), Color(0xFFE0483E));
    default:
      return const _StatusStyle(Color(0xFFEDEDF2), Color(0xFF6B6B76));
  }
}

/// Deterministic avatar color from client name, so the same client
/// always gets the same color without needing it stored on the model.
class _AvatarStyle {
  final Color bg;
  final Color text;
  const _AvatarStyle(this.bg, this.text);
}

const List<_AvatarStyle> _avatarPalette = [
  _AvatarStyle(Color(0xFFE3E0FB), Color(0xFF6C5CE7)),
  _AvatarStyle(Color(0xFFD7EBFB), Color(0xFF2E86DE)),
  _AvatarStyle(Color(0xFFFAD9DA), Color(0xFFE0483E)),
  _AvatarStyle(Color(0xFFD8F3E3), Color(0xFF1E9E5A)),
  _AvatarStyle(Color(0xFFFBF0D2), Color(0xFFC9971E)),
];

_AvatarStyle _avatarStyleFor(String name) {
  final index = name.hashCode.abs() % _avatarPalette.length;
  return _avatarPalette[index];
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// ---------------------------------------------------------------------
/// VIEW MODEL
/// ---------------------------------------------------------------------
class InvoiceListViewModel extends ChangeNotifier {
  List<InvoiceListItem> invoices = [];
  bool isLoading = false;
  String? errorMessage;

  String selectedFilter = 'All';
  String searchQuery = '';

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

    try {
      // TODO: fetch from sqflite / Firestore.
      // Example:
      // final rows = await db.query('invoices');
      // invoices = rows.map((r) => InvoiceListItem(
      //   id: r['id'] as String,
      //   clientName: r['client_name'] as String,
      //   invoiceNumber: r['invoice_number'] as String,
      //   dateLabel: r['date_label'] as String,
      //   amount: (r['amount'] as num).toDouble(),
      //   status: r['status'] as String,
      // )).toList();
      invoices = _mockInvoices;
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

  List<InvoiceListItem> get filteredInvoices {
    final query = searchQuery.trim().toLowerCase();
    return invoices.where((invoice) {
      final matchesFilter =
          selectedFilter == 'All' || invoice.status == selectedFilter;
      final matchesSearch = query.isEmpty ||
          invoice.clientName.toLowerCase().contains(query) ||
          invoice.invoiceNumber.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  // Sample data standing in until the real data source is wired up.
  static final List<InvoiceListItem> _mockInvoices = [
    const InvoiceListItem(
      id: '1',
      clientName: 'Meridian Studio',
      invoiceNumber: 'INV-2026-014',
      dateLabel: '12 Jun',
      amount: 48000,
      status: 'Paid',
    ),
    const InvoiceListItem(
      id: '2',
      clientName: 'Nordic Coffee Co.',
      invoiceNumber: 'INV-2026-013',
      dateLabel: '08 Jun',
      amount: 12500,
      status: 'Sent',
    ),
    const InvoiceListItem(
      id: '3',
      clientName: 'Patel & Sons',
      invoiceNumber: 'INV-2026-012',
      dateLabel: '28 May',
      amount: 86200,
      status: 'Overdue',
    ),
    const InvoiceListItem(
      id: '4',
      clientName: 'Lumen Design',
      invoiceNumber: 'INV-2026-011',
      dateLabel: '24 May',
      amount: 22000,
      status: 'Draft',
    ),
    const InvoiceListItem(
      id: '5',
      clientName: 'Veda Wellness',
      invoiceNumber: 'INV-2026-010',
      dateLabel: '19 May',
      amount: 54750,
      status: 'Paid',
    ),
    const InvoiceListItem(
      id: '6',
      clientName: 'Arc Architects',
      invoiceNumber: 'INV-2026-009',
      dateLabel: '14 May',
      amount: 110000,
      status: 'Sent',
    ),
  ];
}

/// ---------------------------------------------------------------------
/// VIEW
/// ---------------------------------------------------------------------
class InvoiceListView extends StatefulWidget {
  final InvoiceListViewModel? viewModel;

  const InvoiceListView({super.key, this.viewModel});

  @override
  State<InvoiceListView> createState() => _InvoiceListViewState();
}

class _InvoiceListViewState extends State<InvoiceListView> {
  static const Color _primaryPurple = Color(0xFF5B4FE9);

  late final InvoiceListViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? InvoiceListViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadInvoices();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _searchController.dispose();
    // Only dispose a view model we created ourselves.
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  String _formatAmount(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    // Indian-style grouping (e.g. 1,10,000).
    final buffer = StringBuffer();
    final digits = str.split('').reversed.toList();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '₹${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F6),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 12),
                Expanded(child: _buildBody()),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: _buildNewButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Invoices',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF16161C),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune,
              color: Color(0xFF16161C),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _viewModel.setSearchQuery,
          decoration: const InputDecoration(
            hintText: 'Search invoice or client',
            hintStyle: TextStyle(color: Color(0xFF9B9BA5), fontSize: 15),
            prefixIcon: Icon(Icons.search, color: Color(0xFF9B9BA5)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: InvoiceListViewModel.filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = InvoiceListViewModel.filters[index];
          final isSelected = filter == _viewModel.selectedFilter;
          return GestureDetector(
            onTap: () => _viewModel.setFilter(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _primaryPurple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? []
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF6B6B76),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryPurple),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _viewModel.errorMessage!,
              style: const TextStyle(color: Color(0xFF9B9BA5), fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _viewModel.loadInvoices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final invoices = _viewModel.filteredInvoices;
    if (invoices.isEmpty) {
      return const Center(
        child: Text(
          'No invoices found',
          style: TextStyle(color: Color(0xFF9B9BA5), fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadInvoices,
      color: _primaryPurple,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildInvoiceCard(invoices[index]),
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceListItem invoice) {
    final statusStyle = _styleForStatus(invoice.status);
    final avatarStyle = _avatarStyleFor(invoice.clientName);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarStyle.bg,
            child: Text(
              _initialsFor(invoice.clientName),
              style: TextStyle(
                color: avatarStyle.text,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.clientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF16161C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${invoice.invoiceNumber} · ${invoice.dateLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF9B9BA5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(invoice.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF16161C),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusStyle.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  invoice.status,
                  style: TextStyle(
                    color: statusStyle.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewButton() {
    return Material(
      color: _primaryPurple,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          // TODO: Navigate to create-invoice flow.
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'New',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
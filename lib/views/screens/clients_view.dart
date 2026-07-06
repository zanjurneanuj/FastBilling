import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/ClientItem.dart';
import '../../utils/app_colors.dart';
import '../../viewmodels/client_viewmodel.dart';
import '../widgets/empty_state.dart';

class ClientsView extends StatefulWidget {
  const ClientsView({super.key});

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<ClientsViewModel>().loadClients();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClientItem> _filtered(List<ClientItem> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
    c!.name.toLowerCase().contains(q) ||
        c!.email.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ClientsViewModel>(
      builder: (context, vm, _) {
        final clients = _filtered(vm.clients);

        return Scaffold(
          backgroundColor: AppColors.background(context),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Clients',
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        '${vm.clients.length} total',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                // ── Search ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                        color: AppColors.textPrimary(context), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search clients',
                      hintStyle: TextStyle(
                          color: AppColors.textHint(context), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textHint(context), size: 20),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── List ────────────────────────────────────────────
                Expanded(
                  child: vm.isLoading
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                      : clients.isEmpty
                      ? EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: _searchCtrl.text.isEmpty
                        ? 'No clients yet'
                        : 'No results',
                    subtitle: _searchCtrl.text.isEmpty
                        ? 'Tap + Add to create your first client.'
                        : 'Try a different name or email.',
                  )
                      : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: vm.loadClients,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 100),
                      itemCount: clients.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ClientRow(
                        client: clients[i],
                        onTap: () => context
                            .go('/clients/${clients[i].id}'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── FAB ───────────────────────────────────────────────────
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddClientSheet(context, vm),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add_outlined,
                color: Colors.white, size: 20),
            label: const Text('Add',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  // ── Add client bottom sheet ──────────────────────────────────────────────

  void _showAddClientSheet(BuildContext context, ClientsViewModel vm) {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();
    bool saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border(context),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('New Client',
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 18),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Business name *'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Phone (optional)
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone · optional'),
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => saving = true);
                        await vm.addClient(
                          name:  nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: saving
                          ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save Client'),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

// ─── Client Row ───────────────────────────────────────────────────────────────

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client, required this.onTap});
  final ClientItem   client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(children: [
          _ClientAvatar(name: client.name),
          const SizedBox(width: 12),

          // Name + email
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(client.email,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12)),
                ]),
          ),

          // Amount + billed label
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${_fmt(client.totalBilled)}',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('billed',
                style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─── Client Avatar ────────────────────────────────────────────────────────────

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name});
  final String name;

  static const _palettes = [
    (bg: Color(0xFFE8E4FF), fg: Color(0xFF6C5CE7)),
    (bg: Color(0xFFE0F4FF), fg: Color(0xFF0984E3)),
    (bg: Color(0xFFFFE8E8), fg: Color(0xFFE17055)),
    (bg: Color(0xFFE8FFE8), fg: Color(0xFF00B894)),
    (bg: Color(0xFFFFF3E0), fg: Color(0xFFF39C12)),
    (bg: Color(0xFFFFE4F3), fg: Color(0xFFE84393)),
  ];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  ({Color bg, Color fg}) get _color {
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % _palettes.length;
    return _palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      width: 44, height: 44,
      decoration:
      BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(_initials,
            style: TextStyle(
                color: c.fg, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/PdfTemplateService.dart';
import '../../services/ProfileService.dart';
import '../../services/auth_service.dart';
import '../../models/PdfTemplate.dart';
import '../../utils/app_colors.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'PdfTemplateCard.dart';
import 'pdf_templates_page.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _cloudBackup = true;
  bool _appLock     = false;

  @override
  void initState() {
    super.initState();
    // Rebuild the "PDF template" tile whenever the selection changes,
    // whether from this screen's dialog or the full browse page.
    PdfTemplateService.changed.addListener(_onPdfTemplateChanged);
  }

  @override
  void dispose() {
    PdfTemplateService.changed.removeListener(_onPdfTemplateChanged);
    super.dispose();
  }

  void _onPdfTemplateChanged() {
    if (mounted) setState(() {});
  }

  String get _businessName =>
      ProfileService.cached?.name ?? AuthService.currentUser?.displayName ?? 'You';
  String get _businessSub =>
      ProfileService.cached?.gstNumber != null
          ? 'GST: ${ProfileService.cached!.gstNumber}'
          : ProfileService.cached?.address ?? '';
  String get _currency =>
      ProfileService.cached?.currency ?? 'INR';

  String get _initials {
    final parts = _businessName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _businessName.isNotEmpty ? _businessName[0].toUpperCase() : '?';
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = context.watch<ThemeProvider>();
    final vm = context.watch<SettingsViewModel>();

    final themeLabel = switch (themeProvider.themeMode) {
      ThemeMode.light  => 'Light',
      ThemeMode.dark   => 'Dark',
      ThemeMode.system => 'System',
    };

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────
              Text('Settings',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // ── Profile card ──────────────────────────────────────
              _ProfileCard(
                initials:    _initials,
                name:        _businessName,
                sub:         _businessSub,
                onEdit:      () => _showEditProfileDialog(context),
              ),
              const SizedBox(height: 24),

              // ── Branding & Output ─────────────────────────────────
              _SectionLabel('BRANDING & OUTPUT'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  label: 'Logo & accent color',
                  trailing: _ColorDot(),
                  showChevron: true,
                  onTap: () {},
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  label: 'PDF template',
                  trailingText: PdfTemplateService.selected.name,
                  showChevron: true,
                  onTap: () => _showPdfTemplateDialog(context),
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Default currency',
                  trailingText: '₹ $_currency',
                  showChevron: true,
                  onTap: () => _showCurrencyPicker(context),
                ),
              ]),
              const SizedBox(height: 20),

              // ── App ───────────────────────────────────────────────
              _SectionLabel('APP'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _SettingsTile(
                    icon: Icons.cloud_sync_outlined,
                    label: 'Cloud backup',
                    subLabel: _cloudBackup ? 'Last synced 2h ago' : 'Off',
                    subLabelColor: _cloudBackup
                        ? AppColors.primary
                        : AppColors.textSecondary(context),
                    trailing: Switch(
                      value: vm.cloudBackup,
                      onChanged: (v) => context.read<SettingsViewModel>().toggleCloudBackup(v),
                      activeColor: AppColors.primary,
                    )
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark theme',
                  trailingText: themeLabel,
                  showChevron: true,
                  onTap: () => _showThemePicker(context, themeProvider),
                ),
                _Divider(),
                _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'App lock',
                    trailing: Switch(
                      value: vm.appLock,
                      onChanged: (v) => context.read<SettingsViewModel>().toggleAppLock(v),
                      activeColor: AppColors.primary,
                    )
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  trailingText: 'English',
                  showChevron: true,
                  onTap: () => _showLanguagePicker(context),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Account ───────────────────────────────────────────
              _SectionLabel('ACCOUNT'),
              const SizedBox(height: 8),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                  onTap: () => _confirmSignOut(context),
                ),
              ]),
              const SizedBox(height: 32),

              // ── Version footer ────────────────────────────────────
              Center(
                child: Text('Invoice Generator · v1.0.0',
                    style: TextStyle(
                        color: AppColors.textHint(context), fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pickers / dialogs ──────────────────────────────────────────────────────

  void _showThemePicker(BuildContext context, ThemeProvider tp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Text('Dark theme',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              const SizedBox(height: 12),
              ...[
                ('System', ThemeMode.system),
                ('Light',  ThemeMode.light),
                ('Dark',   ThemeMode.dark),
              ].map((pair) => RadioListTile<ThemeMode>(
                title: Text(pair.$1,
                    style: TextStyle(color: AppColors.textPrimary(context))),
                value: pair.$2,
                groupValue: tp.themeMode,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  if (v != null) tp.setTheme(v);
                  Navigator.pop(context);
                },
              )),
            ]),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    const currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Text('Default currency',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              const SizedBox(height: 12),
              ...currencies.map((c) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c,
                    style: TextStyle(color: AppColors.textPrimary(context))),
                trailing: _currency == c
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  // TODO: persist currency change via ProfileService
                  Navigator.pop(context);
                  setState(() {});
                },
              )),
            ]),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Text('Language',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              const SizedBox(height: 12),
              ...['English', 'Hindi', 'Marathi'].map((lang) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lang,
                    style: TextStyle(color: AppColors.textPrimary(context))),
                trailing: lang == 'English'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context),
              )),
            ]),
      ),
    );
  }

  void _showPdfTemplateDialog(BuildContext context) {
    String selectedId = PdfTemplateService.selected.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Text('Choose PDF template',
                  style: TextStyle(
                      color: AppColors.textPrimary(sheetContext),
                      fontWeight: FontWeight.w700,
                      fontSize: 19)),
              const SizedBox(height: 4),
              Text('Select a layout for all your invoices',
                  style: TextStyle(
                      color: AppColors.textSecondary(sheetContext),
                      fontSize: 13)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: PdfTemplateCatalog.quickPick.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (_, i) {
                  final t = PdfTemplateCatalog.quickPick[i];
                  return PdfTemplateCard(
                    template: t,
                    isSelected: t.id == selectedId,
                    onTap: () => setSheetState(() => selectedId = t.id),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PdfTemplatesPage()),
                    );
                  },
                  child: const Text('See more templates',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await PdfTemplateService.select(
                        PdfTemplateCatalog.byId(selectedId));
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('Apply template',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(
        initialName:      ProfileService.cached?.name ?? '',
        initialGst:       ProfileService.cached?.gstNumber ?? '',
        initialAddress:   ProfileService.cached?.address ?? '',
        onSaved: () => setState(() {}), // refresh header once saved
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?',
            style: TextStyle(color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700)),
        content: Text('You will be returned to the login screen.',
            style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<SettingsViewModel>().signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign out',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.initials,
    required this.name,
    required this.sub,
    required this.onEdit,
  });
  final String       initials;
  final String       name;
  final String       sub;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 14),

        // Name + sub
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 13)),
            ],
          ]),
        ),

        // Edit icon
        IconButton(
          onPressed: onEdit,
          icon: Icon(Icons.edit_outlined,
              color: AppColors.textSecondary(context), size: 20),
        ),
      ]),
    );
  }
}

// ─── Edit Profile Dialog ──────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialGst,
    required this.initialAddress,
    required this.onSaved,
  });

  final String initialName;
  final String initialGst;
  final String initialAddress;
  final VoidCallback onSaved;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _nameCtrl    = TextEditingController(text: widget.initialName);
  late final _gstCtrl     = TextEditingController(text: widget.initialGst);
  late final _addressCtrl = TextEditingController(text: widget.initialAddress);

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error  = null;
    });

    try {
      // ProfileService.save() rewrites the whole profile, so we carry over
      // fields this dialog doesn't touch (currency, logo) from the cache.
      await ProfileService.save(
        name:      _nameCtrl.text.trim(),
        address:   _addressCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        currency:  ProfileService.cached?.currency ?? 'INR',
      );

      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Could not save changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Edit profile',
          style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'Business name',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gstCtrl,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'GST number (optional)',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  labelText: 'Address',
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary(context))),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('Save',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(children: children),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subLabel,
    this.subLabelColor,
    this.trailingText,
    this.trailing,
    this.showChevron = false,
    this.labelColor,
    this.iconColor,
    this.onTap,
  });

  final IconData  icon;
  final String    label;
  final String?   subLabel;
  final Color?    subLabelColor;
  final String?   trailingText;
  final Widget?   trailing;
  final bool      showChevron;
  final Color?    labelColor;
  final Color?    iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          // Icon
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon,
                color: iconColor ?? AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),

          // Label + sublabel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: labelColor ?? AppColors.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(subLabel!,
                      style: TextStyle(
                          color: subLabelColor ??
                              AppColors.textSecondary(context),
                          fontSize: 12)),
                ],
              ],
            ),
          ),

          // Trailing widget, text, or chevron
          if (trailing != null)
            trailing!
          else if (trailingText != null)
            Text(trailingText!,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13))
          else
            const SizedBox.shrink(),

          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context), size: 18),
          ],
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 64,
    endIndent: 0,
    color: AppColors.border(context),
  );
}

class _ColorDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 22, height: 22,
    decoration: const BoxDecoration(
        color: AppColors.primary, shape: BoxShape.circle),
  );
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
          color: AppColors.border(context),
          borderRadius: BorderRadius.circular(2)),
    ),
  );
}
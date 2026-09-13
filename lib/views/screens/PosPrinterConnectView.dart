import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../models/PosPrinter.dart';
import '../../services/PosPrinterService.dart';

class PosPrinterConnectView extends StatefulWidget {
  const PosPrinterConnectView({super.key});

  @override
  State<PosPrinterConnectView> createState() => _PosPrinterConnectViewState();
}

class _PosPrinterConnectViewState extends State<PosPrinterConnectView> {
  PrinterConnectionType _selectedType = PrinterConnectionType.wifi;
  bool _scanning = false;
  List<PosPrinterDevice> _devices = [];
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    PosPrinterService.changed.addListener(_onChanged);
    _scan();
  }

  @override
  void dispose() {
    PosPrinterService.changed.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final results = await PosPrinterService.scan(_selectedType);
    if (!mounted) return;
    setState(() {
      _devices = results;
      _scanning = false;
    });
  }

  Future<void> _connect(PosPrinterDevice device) async {
    setState(() => _connectingId = device.id);
    final ok = await PosPrinterService.connect(device);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to ${device.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = PosPrinterService.connectedDevice;
    final isConnected = PosPrinterService.isConnected;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        title: Text('POS printer',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary(context)),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Currently connected banner ────────────────────────────────
            if (isConnected && connected != null) ...[
              _ConnectedBanner(
                device: connected,
                onDisconnect: () => PosPrinterService.disconnect(),
              ),
              const SizedBox(height: 20),
            ],

            // ── Connection type selector ────────────────────────────────
            _ConnectionTypeSelector(
              selected: _selectedType,
              onChanged: (t) {
                setState(() => _selectedType = t);
                _scan();
              },
            ),
            const SizedBox(height: 20),

            // ── Available printers ──────────────────────────────────────
            _SectionLabel('AVAILABLE PRINTERS'),
            const SizedBox(height: 10),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No printers found.',
                    style:
                    TextStyle(color: AppColors.textSecondary(context))),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _devices.length; i++) ...[
                      _PrinterTile(
                        device: _devices[i],
                        isActive: connected?.id == _devices[i].id &&
                            isConnected,
                        isConnecting: _connectingId == _devices[i].id,
                        onConnect: () => _connect(_devices[i]),
                      ),
                      if (i != _devices.length - 1)
                        Divider(
                            height: 1,
                            indent: 60,
                            color: AppColors.border(context)),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // ── Add manually ─────────────────────────────────────────────
            _AddManuallyButton(onTap: () => _showAddManuallySheet(context)),
            const SizedBox(height: 24),

            // ── Receipt settings ────────────────────────────────────────
            _SectionLabel('RECEIPT SETTINGS'),
            const SizedBox(height: 10),
            _ReceiptSettingsCard(
              settings: PosPrinterService.settings,
              onChanged: PosPrinterService.updateSettings,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddManuallySheet(BuildContext context) {
    final ipCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add printer manually',
                style: TextStyle(
                    color: AppColors.textPrimary(sheetContext),
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 4),
            Text('Enter the printer\'s IP address (LAN/WiFi printers)',
                style: TextStyle(
                    color: AppColors.textSecondary(sheetContext),
                    fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Printer name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'IP address', hintText: '192.168.1.100'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (ipCtrl.text.trim().isEmpty) return;
                  final device = PosPrinterDevice(
                    id: ipCtrl.text.trim(),
                    name: nameCtrl.text.trim().isEmpty
                        ? ipCtrl.text.trim()
                        : nameCtrl.text.trim(),
                    type: PrinterConnectionType.wifi,
                    subtitle: '${ipCtrl.text.trim()} · Manual',
                  );
                  Navigator.pop(sheetContext);
                  setState(() => _devices = [..._devices, device]);
                  _connect(device);
                },
                child: const Text('Add & connect',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Connected banner ─────────────────────────────────────────────────────────

class _ConnectedBanner extends StatelessWidget {
  const _ConnectedBanner({required this.device, required this.onDisconnect});
  final PosPrinterDevice device;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(Icons.print_rounded, color: AppColors.success, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 1),
            Text(
                'Connected via ${_typeLabel(device.type)}'
                    '${device.subtitle != null ? " · ${device.subtitle}" : ""}',
                style: TextStyle(
                    color: AppColors.success.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
      Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
            color: AppColors.success, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onDisconnect,
        child: Text('Disconnect',
            style: TextStyle(
                color: AppColors.error.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  String _typeLabel(PrinterConnectionType t) => switch (t) {
    PrinterConnectionType.bluetooth => 'Bluetooth',
    PrinterConnectionType.wifi => 'WiFi/LAN',
    PrinterConnectionType.usb => 'USB',
  };
}

// ─── Connection type selector (segmented control) ─────────────────────────────

class _ConnectionTypeSelector extends StatelessWidget {
  const _ConnectionTypeSelector(
      {required this.selected, required this.onChanged});
  final PrinterConnectionType selected;
  final ValueChanged<PrinterConnectionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (PrinterConnectionType.bluetooth, Icons.bluetooth_rounded, 'Bluetooth'),
      (PrinterConnectionType.wifi, Icons.wifi_rounded, 'WiFi / LAN'),
      (PrinterConnectionType.usb, Icons.usb_rounded, 'USB'),
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = selected == opt.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt.$1 == options.last.$1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border(context)),
                ),
                child: Column(children: [
                  Icon(opt.$2,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary(context)),
                  const SizedBox(height: 4),
                  Text(opt.$3,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary(context))),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Printer tile ─────────────────────────────────────────────────────────────

class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.device,
    required this.isActive,
    required this.isConnecting,
    required this.onConnect,
  });
  final PosPrinterDevice device;
  final bool isActive;
  final bool isConnecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.print_outlined, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            if (device.subtitle != null)
              Text(device.subtitle!,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12)),
          ],
        ),
      ),
      if (isConnecting)
        const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
      else if (isActive)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('Active',
              style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        )
      else
        GestureDetector(
          onTap: onConnect,
          child: Text('Connect',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
    ]),
  );
}

// ─── Add manually button ──────────────────────────────────────────────────────

class _AddManuallyButton extends StatelessWidget {
  const _AddManuallyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        const Text('Add printer manually',
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─── Receipt settings card ─────────────────────────────────────────────────────

class _ReceiptSettingsCard extends StatelessWidget {
  const _ReceiptSettingsCard({required this.settings, required this.onChanged});
  final PosPrinterSettings settings;
  final ValueChanged<PosPrinterSettings> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(children: [
      InkWell(
        onTap: () => _showPaperWidthPicker(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(Icons.crop_portrait_rounded,
                color: AppColors.textSecondary(context), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Paper width',
                  style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            Text('${settings.paperWidthMm}mm',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary(context), size: 18),
          ]),
        ),
      ),
      Divider(height: 1, indent: 48, color: AppColors.border(context)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.qr_code_rounded,
              color: AppColors.textSecondary(context), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Print QR / UPI code',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: settings.printQrOrUpi,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                onChanged(settings.copyWith(printQrOrUpi: v)),
          ),
        ]),
      ),
      Divider(height: 1, indent: 48, color: AppColors.border(context)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded,
              color: AppColors.textSecondary(context), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Auto-print on payment',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: settings.autoPrintOnPayment,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                onChanged(settings.copyWith(autoPrintOnPayment: v)),
          ),
        ]),
      ),
    ]),
  );

  void _showPaperWidthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paper width',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            const SizedBox(height: 12),
            ...[58, 80].map((w) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${w}mm',
                  style: TextStyle(color: AppColors.textPrimary(context))),
              trailing: settings.paperWidthMm == w
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                onChanged(settings.copyWith(paperWidthMm: w));
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

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
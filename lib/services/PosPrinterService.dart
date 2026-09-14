import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

// ESC/POS byte generation (text, columns, qr, cut) — unchanged, still used
// for every transport including the raw WiFi socket below.
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

// Real Bluetooth Classic / BLE / USB transport. Imported under a prefix
// because this package's PrinterConnectionType/PrinterDevice names collide
// with this app's own models in ../models/PosPrinter.dart.
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart' as pkg;

import '../models/PosPrinter.dart';
import 'local_db_service.dart';

class PosPrinterService {
  PosPrinterService._();

  /// Fires whenever connection state, selected device, or settings change.
  /// Same pattern as ProfileService.changed / PdfTemplateService.changed —
  /// listen to this from any StatefulWidget that needs to rebuild.
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static void _notify() => changed.value++;

  static final pkg.PrinterManager _manager = pkg.PrinterManager();

  static PosPrinterDevice? connectedDevice;
  static PrinterConnectionStatus status = PrinterConnectionStatus.disconnected;
  static PosPrinterSettings settings = const PosPrinterSettings();
  static List<PosPrinterDevice> lastScanResults = [];

  /// Package-side devices found by the last scan, keyed by the app's own
  /// PosPrinterDevice.id, so connect() can hand the *exact* discovered
  /// object back to PrinterManager (a BLE device especially can't be safely
  /// reconstructed from just its id string).
  static final Map<String, pkg.PrinterDevice> _discovered = {};

  static bool get isConnected =>
      status == PrinterConnectionStatus.connected && connectedDevice != null;

  // ── Settings persistence ───────────────────────────────────────────────

  static const _settingsKey = 'pos_printer_settings';

  /// Call once at app startup (see main.dart) so `settings` reflects the
  /// user's saved paper width / QR / auto-print choices before any printer
  /// screen reads them.
  static Future<void> loadSettings() async {
    final raw = await LocalDbService.instance.getSetting(_settingsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      settings = PosPrinterSettings(
        paperWidthMm: map['paperWidthMm'] as int? ?? settings.paperWidthMm,
        printQrOrUpi: map['printQrOrUpi'] as bool? ?? settings.printQrOrUpi,
        autoPrintOnPayment:
        map['autoPrintOnPayment'] as bool? ?? settings.autoPrintOnPayment,
      );
      _notify();
    } catch (e) {
      debugPrint('[PosPrinter] failed to load saved settings: $e');
    }
  }

  static void updateSettings(PosPrinterSettings s) {
    settings = s;
    _notify();
    LocalDbService.instance.saveSetting(
      _settingsKey,
      jsonEncode({
        'paperWidthMm': s.paperWidthMm,
        'printQrOrUpi': s.printQrOrUpi,
        'autoPrintOnPayment': s.autoPrintOnPayment,
      }),
    );
  }

  // ── Scanning ────────────────────────────────────────────────────────────

  static Future<List<PosPrinterDevice>> scan(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return _scanBluetooth();
      case PrinterConnectionType.wifi:
        return _scanWifi();
      case PrinterConnectionType.usb:
        return _scanUsb();
    }
  }

  static Future<List<PosPrinterDevice>> _scanBluetooth() async {
    _discovered.removeWhere((_, d) =>
    d.connectionType == pkg.PrinterConnectionType.bluetooth ||
        d.connectionType == pkg.PrinterConnectionType.ble);

    final found = await _manager.scanPrinters(
      types: const {
        pkg.PrinterConnectionType.bluetooth, // Classic SPP — Android only
        pkg.PrinterConnectionType.ble,       // BLE — Android/iOS/Windows
      },
    );

    lastScanResults = found.map((d) {
      final id = switch (d) {
        pkg.BluetoothPrinterDevice() => d.address,
        pkg.BlePrinterDevice() => d.deviceId,
        _ => d.name,
      };
      _discovered[id] = d;
      return PosPrinterDevice(
        id: id,
        name: d.name,
        type: PrinterConnectionType.bluetooth,
        subtitle: d is pkg.BlePrinterDevice ? 'Bluetooth LE' : 'Bluetooth',
      );
    }).toList();

    return lastScanResults;
  }

  /// Real LAN discovery: reads this device's own Wi-Fi IP to find the /24
  /// subnet, then sweeps it for hosts listening on raw TCP port 9100 — the
  /// port virtually every thermal receipt printer listens on. No mDNS, so a
  /// printer needs to actually accept a bare TCP connect on 9100 to show up;
  /// that's the same thing _connectWifi below relies on, so anything found
  /// here is guaranteed connectable.
  static Future<List<PosPrinterDevice>> _scanWifi() async {
    const port = 9100;
    const perHostTimeout = Duration(milliseconds: 350);
    const batchSize = 32;

    String? ip;
    try {
      ip = await NetworkInfo().getWifiIP();
    } catch (e) {
      debugPrint('[PosPrinter] could not read Wi-Fi IP: $e');
    }

    final parts = ip?.split('.');
    if (parts == null || parts.length != 4) {
      // Not on Wi-Fi, or the platform wouldn't hand back an IP — nothing to
      // scan. Empty result reads as "no printers found" in the UI.
      lastScanResults = const [];
      return lastScanResults;
    }
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final found = <PosPrinterDevice>[];
    for (var start = 1; start <= 254; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, 254);
      final hosts = await Future.wait([
        for (var h = start; h <= end; h++) _probeHost('$subnet.$h', port, perHostTimeout),
      ]);
      found.addAll(hosts.whereType<PosPrinterDevice>());
    }

    lastScanResults = found;
    return lastScanResults;
  }

  static Future<PosPrinterDevice?> _probeHost(
      String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      unawaited(socket.close());
      return PosPrinterDevice(
        id: host,
        name: 'Network printer',
        type: PrinterConnectionType.wifi,
        subtitle: '$host · Port $port',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<PosPrinterDevice>> _scanUsb() async {
    _discovered
        .removeWhere((_, d) => d.connectionType == pkg.PrinterConnectionType.usb);

    final found = await _manager.scanPrinters(
      types: const {pkg.PrinterConnectionType.usb},
    );

    lastScanResults = found.whereType<pkg.UsbPrinterDevice>().map((d) {
      _discovered[d.identifier] = d;
      return PosPrinterDevice(
        id: d.identifier,
        name: d.name,
        type: PrinterConnectionType.usb,
        subtitle: 'USB',
      );
    }).toList();

    return lastScanResults;
  }

  // ── Connection ──────────────────────────────────────────────────────────

  static Future<bool> connect(PosPrinterDevice device) async {
    status = PrinterConnectionStatus.connecting;
    _notify();

    try {
      switch (device.type) {
        case PrinterConnectionType.bluetooth:
          await _connectBluetooth(device);
          break;
        case PrinterConnectionType.wifi:
          await _connectWifi(device);
          break;
        case PrinterConnectionType.usb:
          await _connectUsb(device);
          break;
      }
      connectedDevice = device;
      status = PrinterConnectionStatus.connected;
      _notify();
      return true;
    } catch (e) {
      debugPrint('[PosPrinter] connect failed: $e');
      status = PrinterConnectionStatus.error;
      _notify();
      return false;
    }
  }

  static Socket? _wifiSocket;

  static Future<void> _connectBluetooth(PosPrinterDevice device) async {
    final pkgDevice = _discovered[device.id];
    if (pkgDevice == null) {
      throw StateError('Bluetooth device ${device.id} was not in the last scan.');
    }
    await _manager.connect(pkgDevice);
  }

  static Future<void> _connectWifi(PosPrinterDevice device) async {
    _wifiSocket = await Socket.connect(
      device.id,
      9100,
      timeout: const Duration(seconds: 5),
    );
  }

  static Future<void> _connectUsb(PosPrinterDevice device) async {
    final pkgDevice = _discovered[device.id];
    if (pkgDevice == null) {
      throw StateError('USB device ${device.id} was not in the last scan.');
    }
    await _manager.connect(pkgDevice);
  }

  static Future<void> disconnect() async {
    try {
      await _wifiSocket?.close();
    } catch (_) {}
    _wifiSocket = null;

    try {
      await _manager.disconnect();
    } catch (_) {}

    connectedDevice = null;
    status = PrinterConnectionStatus.disconnected;
    _notify();
  }

  // ── Printing ────────────────────────────────────────────────────────────

  /// Builds an ESC/POS receipt and sends it to the connected printer.
  /// Returns false immediately (no-op) if nothing is connected.
  static Future<bool> printReceipt({
    required String businessName,
    required String businessSub, // e.g. "Bengaluru 560001 · GST: unregistered"
    required String invoiceNo,
    required String date,
    required String billTo,
    required List<PosReceiptLine> items,
    required double subtotal,
    required double gstAmt,
    required double total,
    String? upiPayeeString, // e.g. "upi://pay?pa=you@bank&am=1234&cu=INR"
  }) async {
    if (!isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final paper =
      settings.paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(paper, profile);

      List<int> bytes = [];

      bytes += generator.text(
        businessName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      if (businessSub.isNotEmpty) {
        bytes += generator.text(businessSub,
            styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.hr();
      bytes += generator.text('Inv#: $invoiceNo   $date');
      bytes += generator.text('Bill to: $billTo');
      bytes += generator.hr();

      for (final item in items) {
        bytes += generator.row([
          PosColumn(text: item.name, width: 6),
          PosColumn(
            text: '${item.qty.toStringAsFixed(0)}x${item.rate.toStringAsFixed(0)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: item.total.toStringAsFixed(0),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 8),
        PosColumn(
          text: subtotal.toStringAsFixed(0),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (gstAmt > 0) {
        bytes += generator.row([
          PosColumn(text: 'GST', width: 8),
          PosColumn(
            text: gstAmt.toStringAsFixed(0),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      bytes += generator.row([
        PosColumn(
            text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(
          text: total.toStringAsFixed(0),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      if (settings.printQrOrUpi && upiPayeeString != null) {
        bytes += generator.feed(1);
        bytes += generator.qrcode(upiPayeeString);
        bytes += generator.text('Scan to pay via UPI',
            styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.feed(1);
      bytes += generator.text('*** THANK YOU ***',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await _sendBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('[PosPrinter] print failed: $e');
      return false;
    }
  }

  static Future<void> _sendBytes(List<int> bytes) async {
    if (connectedDevice == null) return;
    switch (connectedDevice!.type) {
      case PrinterConnectionType.wifi:
        _wifiSocket?.add(Uint8List.fromList(bytes));
        await _wifiSocket?.flush();
        break;
      case PrinterConnectionType.bluetooth:
      case PrinterConnectionType.usb:
        await _manager.printBytes(bytes);
        break;
    }
  }
}

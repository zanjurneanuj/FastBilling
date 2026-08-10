import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

// NOTE — packages needed for real hardware I/O (add to pubspec.yaml):
//   esc_pos_utils_plus     → builds ESC/POS command bytes (text, columns, qr, cut)
//   print_bluetooth_thermal (or flutter_bluetooth_serial) → Bluetooth transport
//   usb_serial              → USB transport
// WiFi/LAN printing needs no extra package — thermal printers on the same
// network almost always listen on raw TCP port 9100, so dart:io Socket works.
//
// This service is written so each transport is isolated behind small private
// methods (_connectBluetooth/_connectWifi/_connectUsb, _sendBytes). Swap the
// TODO-marked bodies for real plugin calls once you've picked your packages —
// nothing in the public API (scan/connect/printReceipt) needs to change.
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/PosPrinter.dart';

class PosPrinterService {
  PosPrinterService._();

  /// Fires whenever connection state, selected device, or settings change.
  /// Same pattern as ProfileService.changed / PdfTemplateService.changed —
  /// listen to this from any StatefulWidget that needs to rebuild.
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static void _notify() => changed.value++;

  static PosPrinterDevice? connectedDevice;
  static PrinterConnectionStatus status = PrinterConnectionStatus.disconnected;
  static PosPrinterSettings settings = const PosPrinterSettings();
  static List<PosPrinterDevice> lastScanResults = [];

  static bool get isConnected =>
      status == PrinterConnectionStatus.connected && connectedDevice != null;

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
    // TODO: replace with real discovery, e.g.:
    //   final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    await Future.delayed(const Duration(milliseconds: 800));
    lastScanResults = const [
      PosPrinterDevice(
        id: '00:11:22:AA:BB:CC',
        name: 'Epson TM-T20 III',
        type: PrinterConnectionType.bluetooth,
        subtitle: 'Thermal 58mm',
      ),
    ];
    return lastScanResults;
  }

  static Future<List<PosPrinterDevice>> _scanWifi() async {
    // TODO: replace with real LAN discovery (mDNS, or a quick port-9100 sweep
    // across the subnet). Left as static entries here so the UI is testable
    // without hardware.
    await Future.delayed(const Duration(milliseconds: 800));
    lastScanResults = const [
      PosPrinterDevice(
        id: '192.168.1.42',
        name: 'Epson TM-T20 III',
        type: PrinterConnectionType.wifi,
        subtitle: '192.168.1.42 · Thermal 58mm',
      ),
      PosPrinterDevice(
        id: '192.168.1.51',
        name: 'Rongta RP58',
        type: PrinterConnectionType.wifi,
        subtitle: '192.168.1.51 · Thermal 58mm',
      ),
    ];
    return lastScanResults;
  }

  static Future<List<PosPrinterDevice>> _scanUsb() async {
    // TODO: replace with real USB device enumeration, e.g. usb_serial plugin.
    await Future.delayed(const Duration(milliseconds: 500));
    lastScanResults = const [
      PosPrinterDevice(
        id: 'usb:001',
        name: 'Xprinter XP-80C',
        type: PrinterConnectionType.usb,
        subtitle: 'USB · Thermal 80mm',
      ),
    ];
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
    // TODO: e.g. await PrintBluetoothThermal.connect(macPrinterAddress: device.id);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  static Future<void> _connectWifi(PosPrinterDevice device) async {
    _wifiSocket = await Socket.connect(
      device.id,
      9100,
      timeout: const Duration(seconds: 5),
    );
  }

  static Future<void> _connectUsb(PosPrinterDevice device) async {
    // TODO: e.g. final port = await UsbSerial.create(vid, pid); await port.open();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  static Future<void> disconnect() async {
    try {
      await _wifiSocket?.close();
    } catch (_) {}
    _wifiSocket = null;
    connectedDevice = null;
    status = PrinterConnectionStatus.disconnected;
    _notify();
  }

  // ── Settings ────────────────────────────────────────────────────────────

  static void updateSettings(PosPrinterSettings s) {
    settings = s;
    _notify();
    // TODO: persist to local storage (Hive/shared_prefs), same as your other
    // app settings, so this survives app restarts.
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
      // TODO: e.g. await PrintBluetoothThermal.writeBytes(bytes);
        break;
      case PrinterConnectionType.usb:
      // TODO: e.g. await usbPort.write(Uint8List.fromList(bytes));
        break;
    }
  }
}
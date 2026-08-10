// ─── POS Printer models ─────────────────────────────────────────────────────

enum PrinterConnectionType { bluetooth, wifi, usb }

enum PrinterConnectionStatus { disconnected, connecting, connected, error }

class PosPrinterDevice {
  final String id; // MAC address (bluetooth) / IP (wifi) / port path (usb)
  final String name;
  final PrinterConnectionType type;
  final String? subtitle; // e.g. "192.168.1.42 · Thermal 58mm"

  const PosPrinterDevice({
    required this.id,
    required this.name,
    required this.type,
    this.subtitle,
  });
}

class PosPrinterSettings {
  final int paperWidthMm; // 58 or 80
  final bool printQrOrUpi;
  final bool autoPrintOnPayment;

  const PosPrinterSettings({
    this.paperWidthMm = 58,
    this.printQrOrUpi = true,
    this.autoPrintOnPayment = false,
  });

  PosPrinterSettings copyWith({
    int? paperWidthMm,
    bool? printQrOrUpi,
    bool? autoPrintOnPayment,
  }) =>
      PosPrinterSettings(
        paperWidthMm: paperWidthMm ?? this.paperWidthMm,
        printQrOrUpi: printQrOrUpi ?? this.printQrOrUpi,
        autoPrintOnPayment: autoPrintOnPayment ?? this.autoPrintOnPayment,
      );
}

/// A single printable line item (kept separate from your invoice LineItem
/// model so the printer package has no dependency on the invoice viewmodel).
class PosReceiptLine {
  final String name;
  final double qty;
  final double rate;

  const PosReceiptLine({
    required this.name,
    required this.qty,
    required this.rate,
  });

  double get total => qty * rate;
}
import 'package:flutter/material.dart';

import '../../models/PosPrinter.dart';
import '../../services/PosPrinterService.dart';

/// Full-screen thermal receipt preview + print action.
/// Push this with the invoice data you want printed, e.g.:
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => PrintReceiptPreviewView(
///     businessName: vm.businessName,
///     businessSub: 'Bengaluru 560001 · unregistered',
///     invoiceNo: invoice.number,
///     date: DateFormat('d MMM yyyy, h:mm a').format(DateTime.now()),
///     billTo: invoice.clientName,
///     items: invoice.items
///         .map((i) => PosReceiptLine(name: i.name, qty: i.qty, rate: i.rate))
///         .toList(),
///     subtotal: invoice.subtotal,
///     gstAmt: invoice.gstAmt,
///     total: invoice.grandTotal,
///     upiPayeeString: 'upi://pay?pa=you@bank&am=${invoice.grandTotal}&cu=INR',
///   ),
/// ));
/// ```
class PrintReceiptPreviewView extends StatefulWidget {
  const PrintReceiptPreviewView({
    super.key,
    required this.businessName,
    required this.businessSub,
    required this.invoiceNo,
    required this.date,
    required this.billTo,
    required this.items,
    required this.subtotal,
    required this.gstAmt,
    required this.total,
    this.gstPercent,
    this.upiPayeeString,
  });

  final String businessName;
  final String businessSub;
  final String invoiceNo;
  final String date;
  final String billTo;
  final List<PosReceiptLine> items;
  final double subtotal;
  final double gstAmt;
  final double total;
  final double? gstPercent;
  final String? upiPayeeString;

  @override
  State<PrintReceiptPreviewView> createState() =>
      _PrintReceiptPreviewViewState();
}

class _PrintReceiptPreviewViewState extends State<PrintReceiptPreviewView> {
  bool _printing = false;

  Future<void> _print() async {
    if (!PosPrinterService.isConnected) {
      _showSnack('No printer connected');
      return;
    }

    setState(() => _printing = true);
    final ok = await PosPrinterService.printReceipt(
      businessName: widget.businessName,
      businessSub: widget.businessSub,
      invoiceNo: widget.invoiceNo,
      date: widget.date,
      billTo: widget.billTo,
      items: widget.items,
      subtotal: widget.subtotal,
      gstAmt: widget.gstAmt,
      total: widget.total,
      upiPayeeString: widget.upiPayeeString,
    );
    if (!mounted) return;
    setState(() => _printing = false);
    _showSnack(ok ? 'Sent to printer' : 'Print failed — check connection');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final paperWidth = PosPrinterService.settings.paperWidthMm;

    return Scaffold(
      backgroundColor: const Color(0xFF16181D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Print receipt',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _ReceiptCard(
                    businessName: widget.businessName,
                    businessSub: widget.businessSub,
                    invoiceNo: widget.invoiceNo,
                    date: widget.date,
                    billTo: widget.billTo,
                    items: widget.items,
                    subtotal: widget.subtotal,
                    gstAmt: widget.gstAmt,
                    gstPercent: widget.gstPercent,
                    total: widget.total,
                    showQr: PosPrinterService.settings.printQrOrUpi &&
                        widget.upiPayeeString != null,
                  ),
                ),
              ),
            ),

            // ── Bottom bar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(children: [
                OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3A3D46)),
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.settings_outlined,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text('Width: ${paperWidth}mm',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _printing ? null : _print,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4FCF),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _printing
                        ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.print_rounded,
                            size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Print now',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Receipt card mockup ───────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.businessName,
    required this.businessSub,
    required this.invoiceNo,
    required this.date,
    required this.billTo,
    required this.items,
    required this.subtotal,
    required this.gstAmt,
    required this.total,
    required this.showQr,
    this.gstPercent,
  });

  final String businessName;
  final String businessSub;
  final String invoiceNo;
  final String date;
  final String billTo;
  final List<PosReceiptLine> items;
  final double subtotal;
  final double gstAmt;
  final double total;
  final double? gstPercent;
  final bool showQr;

  static const _mono = TextStyle(
      fontFamily: 'monospace', color: Colors.black87, fontSize: 12, height: 1.5);

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(businessName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        if (businessSub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(businessSub, textAlign: TextAlign.center, style: _mono),
        ],
        const SizedBox(height: 10),
        const _DashedLine(),
        const SizedBox(height: 6),
        Text('$invoiceNo   $date', style: _mono),
        Text('Bill to: $billTo', style: _mono),
        const SizedBox(height: 6),
        const _DashedLine(),
        const SizedBox(height: 6),
        ...items.map((i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: Text(i.name,
                    style: _mono, overflow: TextOverflow.ellipsis)),
            Expanded(
                flex: 2,
                child: Text(
                    '${i.qty.toStringAsFixed(0)}x${i.rate.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: _mono)),
            Expanded(
                flex: 2,
                child: Text(i.total.toStringAsFixed(0),
                    textAlign: TextAlign.right, style: _mono)),
          ]),
        )),
        const SizedBox(height: 6),
        const _DashedLine(),
        const SizedBox(height: 6),
        _TotalLine('Subtotal', subtotal.toStringAsFixed(0)),
        if (gstAmt > 0)
          _TotalLine(
              gstPercent != null
                  ? 'GST ${gstPercent!.toStringAsFixed(0)}%'
                  : 'GST',
              gstAmt.toStringAsFixed(0)),
        const SizedBox(height: 4),
        _TotalLine('TOTAL', '₹${total.toStringAsFixed(0)}', bold: true),
        if (showQr) ...[
          const SizedBox(height: 14),
          const Center(
            child: Icon(Icons.qr_code_2_rounded, size: 84, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text('Scan or pay via UPI',
              textAlign: TextAlign.center, style: _mono),
        ],
        const SizedBox(height: 12),
        Text('*** PAID · THANK YOU ***',
            textAlign: TextAlign.center,
            style: _mono.copyWith(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                color: Colors.black87)),
        Text(value,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                color: Colors.black87)),
      ],
    ),
  );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        children: List.generate(
          count,
              (_) => Padding(
            padding: const EdgeInsets.only(right: dashSpace),
            child: Container(width: dashWidth, height: 1, color: Colors.black38),
          ),
        ),
      );
    });
  }
}
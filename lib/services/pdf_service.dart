import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/InvoiceDetail.dart';
import '../models/PdfTemplate.dart';

/// Builds an A4 invoice PDF from an [InvoiceDetail], styled from the
/// invoice's active [PdfTemplate] — mirrors the on-screen preview layout
/// (header band in the template color, bill-to, line items, totals) so the
/// exported PDF and the in-app preview match.
class PdfService {
  PdfService._();

  static Future<pw.Document> buildInvoicePdf(
      InvoiceDetail invoice, PdfTemplate template) async {
    final doc = pw.Document();

    final headerColor = PdfColor.fromInt(template.headerColor.toARGB32());
    final accentColor = PdfColor.fromInt(template.accentColor.toARGB32());
    final onHeader = template.darkHeader ? PdfColors.white : PdfColors.black;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header band ──────────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: headerColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(invoice.senderName.isEmpty
                            ? ' ' : invoice.senderName,
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: onHeader)),
                        if (invoice.senderAddress.isNotEmpty)
                          pw.Text(invoice.senderAddress,
                              style: pw.TextStyle(fontSize: 9, color: onHeader)),
                        if (invoice.senderGst != null)
                          pw.Text('GSTIN: ${invoice.senderGst}',
                              style: pw.TextStyle(fontSize: 9, color: onHeader)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE',
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: onHeader,
                                letterSpacing: 1.5)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.invoiceNumber,
                            style: pw.TextStyle(fontSize: 10, color: onHeader)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ── Bill to / issued ─────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(invoice.clientName,
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoice.clientEmail,
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('ISSUED',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(invoice.issuedDate,
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // ── Line items table ─────────────────────────────────────
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(children: [
                    _headerCell('DESCRIPTION'),
                    _headerCell('QTY'),
                    _headerCell('AMOUNT', alignRight: true),
                  ]),
                  ...invoice.items.map((item) => pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(item.name,
                          style: pw.TextStyle(color: accentColor, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(item.qty.toStringAsFixed(0),
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(_fmtFull(item.total),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ),
                  ])),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // ── Totals ────────────────────────────────────────────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _totalRow('Subtotal', _fmtFull(invoice.subtotal)),
                    _totalRow('GST ${invoice.gstPercent.toStringAsFixed(0)}%',
                        _fmtFull(invoice.gstAmt)),
                    if (invoice.discountAmt > 0)
                      _totalRow('Discount', '-${_fmtFull(invoice.discountAmt)}'),
                    pw.SizedBox(height: 6),
                    pw.Text('Total ₹${_fmtFull(invoice.grandTotal)}',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: accentColor)),
                  ],
                ),
              ),

              if (invoice.note != null && invoice.note!.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(invoice.note!,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700)),
                ),
              ],
            ],
          );
        },
      ),
    );

    return doc;
  }

  static pw.Widget _headerCell(String text, {bool alignRight = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text,
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(children: [
      pw.Text('$label   ',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
    ]),
  );

  static String _fmtFull(double v) {
    final s = v.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final groups = <String>[];
    var r = rest;
    while (r.length > 2) {
      groups.insert(0, r.substring(r.length - 2));
      r = r.substring(0, r.length - 2);
    }
    if (r.isNotEmpty) groups.insert(0, r);
    return '${groups.join(',')},$last3';
  }
}

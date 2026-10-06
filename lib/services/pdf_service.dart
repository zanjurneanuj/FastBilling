import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/InvoiceAttachment.dart';
import '../models/InvoiceDetail.dart';
import '../models/InvoiceSection.dart';
import '../models/InvoiceLineItem.dart';
import '../models/PdfTemplate.dart';
import '../utils/amount_in_words.dart';
import '../utils/indian_states.dart';

/// Builds an A4 invoice PDF from an [InvoiceDetail] in the layout of the
/// given [PdfTemplate], with body sections in the user's [SectionLayout].
/// Every layout prints the same fields — seller and buyer GST details,
/// HSN, per-item GST, CGST/SGST or IGST split, amount in words, bank +
/// UPI QR, terms and signatory — they differ only in structure and
/// decoration.
class PdfService {
  PdfService._();

  static _FontBytes? _fonts;

  /// Noto Sans is bundled because the PDF's built-in Helvetica has no ₹.
  /// Raw bytes are cached so they can be handed to a background isolate.
  static Future<_FontBytes> _loadFonts() async {
    Future<Uint8List> load(String p) async =>
        (await rootBundle.load(p)).buffer.asUint8List();
    return _fonts ??= _FontBytes(
      await load('assets/fonts/NotoSans-Regular.ttf'),
      await load('assets/fonts/NotoSans-Bold.ttf'),
      await load('assets/fonts/GreatVibes-Regular.ttf'),
    );
  }

  /// The finished PDF bytes, laid out on a background isolate so building
  /// (font parsing, table layout, image decoding) never blocks the UI.
  /// Use this for preview, print and share.
  static Future<Uint8List> buildInvoicePdfBytes(
    InvoiceDetail invoice,
    PdfTemplate template, {
    SectionLayout sections = SectionLayout.standard,
  }) async {
    final fonts = await _loadFonts();
    if (kIsWeb) {
      return (await _build(invoice, template, sections, fonts)).save();
    }
    return Isolate.run(() async =>
        (await _build(invoice, template, sections, fonts)).save());
  }

  /// Same document on the calling isolate, for callers that need the
  /// [pw.Document] itself.
  static Future<pw.Document> buildInvoicePdf(
    InvoiceDetail invoice,
    PdfTemplate template, {
    SectionLayout sections = SectionLayout.standard,
  }) async =>
      _build(invoice, template, sections, await _loadFonts());

  static Future<pw.Document> _build(InvoiceDetail invoice, PdfTemplate template,
      SectionLayout sections, _FontBytes fonts) async {
    pw.ImageProvider? logo;
    final path = invoice.senderLogoPath;
    if (!kIsWeb && path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) logo = pw.MemoryImage(f.readAsBytesSync());
      } catch (_) {
        logo = null; // unreadable logo — fall back to the initials badge
      }
    }

    pw.Font ttf(Uint8List b) => pw.Font.ttf(b.buffer.asByteData());
    final b = _Builder(invoice, template, ttf(fonts.script), logo, sections);
    final theme =
        pw.ThemeData.withFont(base: ttf(fonts.regular), bold: ttf(fonts.bold));
    final doc = pw.Document(
      title: 'Invoice ${invoice.invoiceNumber}',
      author: invoice.senderName,
      theme: theme,
    );
    doc.addPage(switch (template.layout) {
      TemplateLayout.simple => b.simple(),
      TemplateLayout.logoHeader => b.logoHeader(),
      TemplateLayout.banner => b.banner(),
      TemplateLayout.ribbon => b.ribbon(),
      TemplateLayout.gstClassic => b.gstClassic(),
      TemplateLayout.diagonal => b.diagonal(),
      TemplateLayout.darkCard => b.darkCard(),
    });
    await _addAttachmentPages(doc, invoice);
    return doc;
  }

  /// One page per image attachment, after the invoice. Unreadable or
  /// unreachable attachments are skipped rather than failing the PDF.
  static Future<void> _addAttachmentPages(
      pw.Document doc, InvoiceDetail inv) async {
    final images = <(String, pw.ImageProvider)>[];
    for (final a in inv.attachments) {
      final bytes = await _attachmentBytes(a);
      if (bytes == null) continue;
      try {
        images.add((a.name, pw.MemoryImage(bytes)));
      } catch (_) {
        // not a decodable image — skip
      }
    }
    for (final (n, (name, img)) in images.indexed) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Attachment ${n + 1} of ${images.length}  ·  ${inv.invoiceNumber}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(name,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 10),
            pw.Expanded(
                child: pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))),
          ],
        ),
      ));
    }
  }

  static Future<Uint8List?> _attachmentBytes(InvoiceAttachment a) async {
    if (kIsWeb) return null;
    try {
      if (a.path != null && File(a.path!).existsSync()) {
        return await File(a.path!).readAsBytes();
      }
      if (a.url != null) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10);
        try {
          final req = await client.getUrl(Uri.parse(a.url!));
          final res = await req.close().timeout(const Duration(seconds: 20));
          if (res.statusCode != 200) return null;
          final b = BytesBuilder(copy: false);
          await for (final chunk in res) {
            b.add(chunk);
          }
          return b.takeBytes();
        } finally {
          client.close();
        }
      }
    } catch (_) {
      // offline / deleted — leave it out of the PDF
    }
    return null;
  }
}

class _FontBytes {
  final Uint8List regular, bold, script;
  const _FontBytes(this.regular, this.bold, this.script);
}

// ═══════════════════════════════════════════════════════════════════════════
// Builder — shared blocks + one method per layout
// ═══════════════════════════════════════════════════════════════════════════

class _Builder {
  _Builder(this.inv, this.t, this.script, this.logo, this.sections)
      : accent = PdfColor.fromInt(t.accentColor.toARGB32()),
        onAccent = t.accentColor.computeLuminance() < 0.4
            ? PdfColors.white
            : PdfColors.black;

  final InvoiceDetail inv;
  final PdfTemplate t;
  final pw.Font script;
  final pw.ImageProvider? logo;
  final SectionLayout sections;

  final PdfColor accent;
  final PdfColor onAccent; // readable text color on top of [accent]

  static const ink = PdfColor.fromInt(0xFF1F2933);
  static const muted = PdfColor.fromInt(0xFF6B7280);
  static const line = PdfColor.fromInt(0xFFD9DDE3);
  static const zebra = PdfColor.fromInt(0xFFF5F6F8);

  static final _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _plain = NumberFormat('#,##,##0.00', 'en_IN');

  String money(double v) => _money.format(v);
  String plain(double v) => _plain.format(v);
  static String num0(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // ── Text helpers ──────────────────────────────────────────────────────────
  pw.TextStyle s(double size,
          {bool bold = false, PdfColor color = ink, double? spacing}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
        letterSpacing: spacing,
      );

  pw.Widget txt(String text, double size,
          {bool bold = false,
          PdfColor color = ink,
          pw.TextAlign? align,
          double? spacing}) =>
      pw.Text(text,
          textAlign: align,
          style: s(size, bold: bold, color: color, spacing: spacing));

  pw.Widget label(String text, {PdfColor color = muted}) =>
      txt(text.toUpperCase(), 7.5, bold: true, color: color, spacing: 0.6);

  // ── Party / meta data ─────────────────────────────────────────────────────
  List<String> get sellerLines => [
        if (inv.senderAddress.trim().isNotEmpty) inv.senderAddress.trim(),
        if (_has(inv.senderPhone)) 'Phone: ${inv.senderPhone}',
        if (_has(inv.senderEmail)) inv.senderEmail!,
        if (_has(inv.senderGst)) 'GSTIN: ${inv.senderGst}',
        if (_has(inv.senderPan)) 'PAN: ${inv.senderPan}',
        if (IndianStates.label(gstin: inv.senderGst, state: inv.senderState)
            case final st?)
          'State: $st',
      ];

  List<String> get buyerLines => [
        if (_has(inv.clientAddress)) inv.clientAddress!,
        if (_has(inv.clientPhone)) 'Phone: ${inv.clientPhone}',
        if (inv.clientEmail.trim().isNotEmpty) inv.clientEmail,
        if (_has(inv.clientGstin)) 'GSTIN: ${inv.clientGstin}',
        if (IndianStates.label(gstin: inv.clientGstin, state: inv.clientState)
            case final st?)
          'State: $st',
      ];

  List<(String, String)> get metaPairs => [
        ('Invoice No.', inv.invoiceNumber),
        ('Date', inv.issuedDate),
        if (inv.dueDate != null)
          ('Due Date', DateFormat('d MMM yyyy').format(inv.dueDate!)),
        if (_has(inv.poNumber)) ('PO No.', inv.poNumber!),
        if (inv.placeOfSupply case final p?) ('Place of Supply', p),
      ];

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  String get sellerName =>
      inv.senderName.trim().isEmpty ? 'Your Business' : inv.senderName;

  // ── Building blocks ───────────────────────────────────────────────────────

  /// Logo image, or an initials badge in the accent color.
  pw.Widget logoBox(double size, {PdfColor? bg, PdfColor? fg}) {
    if (logo != null) {
      return pw.SizedBox(
          width: size, height: size, child: pw.Image(logo!, fit: pw.BoxFit.contain));
    }
    final words = sellerName.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'
        : sellerName.substring(0, 1);
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
          color: bg ?? accent, borderRadius: pw.BorderRadius.circular(size / 5)),
      child: txt(initials.toUpperCase(), size * 0.38,
          bold: true, color: fg ?? onAccent),
    );
  }

  pw.Widget party(String title, String name, List<String> lines,
      {PdfColor nameColor = ink, PdfColor lineColor = muted, PdfColor? titleColor}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        label(title, color: titleColor ?? muted),
        pw.SizedBox(height: 3),
        txt(name.isEmpty ? '—' : name, 11, bold: true, color: nameColor),
        pw.SizedBox(height: 2),
        for (final l in lines) txt(l, 8.5, color: lineColor),
      ],
    );
  }

  pw.Widget metaTable({PdfColor labelColor = muted, PdfColor valueColor = ink, double width = 200}) {
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        children: [
          for (final (k, v) in metaPairs)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(children: [
                pw.SizedBox(width: 82, child: txt(k, 8.5, bold: true, color: labelColor)),
                pw.Expanded(
                    child: txt(v, 8.5, color: valueColor, align: pw.TextAlign.right)),
              ]),
            ),
        ],
      ),
    );
  }

  bool get _anyHsn => inv.items.any((i) => i.hsnCode.trim().isNotEmpty);

  String _itemSub(InvoiceLineItem i) => [
        if (i.description.trim().isNotEmpty) i.description.trim(),
        if (i.batchNo.trim().isNotEmpty) 'Batch: ${i.batchNo.trim()}',
        if (i.expiry.trim().isNotEmpty) 'Exp: ${i.expiry.trim()}',
      ].join('  ·  ');

  /// Line-item table. [bordered] draws a full grid (GST classic style);
  /// otherwise rows are separated by zebra striping.
  pw.Widget itemsTable({
    required PdfColor headerBg,
    required PdfColor headerFg,
    PdfColor? stripe,
    bool bordered = false,
    PdfColor borderColor = line,
  }) {
    final hsn = _anyHsn;
    final disc = inv.items.any((i) => i.discountAmount > 0);

    // (header, width, right-aligned) — optional columns only when used.
    final cols = <(String, pw.TableColumnWidth, bool)>[
      ('#', const pw.FixedColumnWidth(20), false),
      ('Item', const pw.FlexColumnWidth(4), false),
      if (hsn) ('HSN/SAC', const pw.FlexColumnWidth(1.4), false),
      ('Qty', const pw.FlexColumnWidth(1.3), true),
      ('Rate', const pw.FlexColumnWidth(1.5), true),
      if (disc) ('Disc', const pw.FlexColumnWidth(1.1), true),
      ('GST', const pw.FlexColumnWidth(0.9), true),
      ('Amount', const pw.FlexColumnWidth(1.7), true),
    ];

    pw.Widget cell(pw.Widget child, {bool right = false}) => pw.Container(
          alignment: right ? pw.Alignment.topRight : pw.Alignment.topLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: child,
        );

    String discText(InvoiceLineItem i) {
      if (i.discountAmount <= 0) return '—';
      return i.discountType == DiscountType.percent
          ? '${num0(i.discountValue)}%'
          : plain(i.discountAmount);
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: headerBg),
        children: [
          for (final (h, _, right) in cols)
            cell(txt(h, 8, bold: true, color: headerFg), right: right),
        ],
      ),
    ];

    for (var n = 0; n < inv.items.length; n++) {
      final i = inv.items[n];
      final sub = _itemSub(i);
      final inclusive = i.taxInclusive && i.gstPercent != null;
      rows.add(pw.TableRow(
        decoration: (!bordered && stripe != null && n.isOdd)
            ? pw.BoxDecoration(color: stripe)
            : null,
        children: [
          cell(txt('${n + 1}', 8.5, color: muted)),
          cell(pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              txt(i.name.isEmpty ? '—' : i.name, 9, bold: true),
              if (sub.isNotEmpty) txt(sub, 7.5, color: muted),
            ],
          )),
          if (hsn) cell(txt(i.hsnCode.isEmpty ? '—' : i.hsnCode, 8.5)),
          cell(txt('${num0(i.qty)} ${i.unit}', 8.5), right: true),
          cell(txt(plain(i.rate), 8.5), right: true),
          if (disc) cell(txt(discText(i), 8.5), right: true),
          cell(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                txt('${num0(i.taxRate(inv.gstPercent))}%', 8.5),
                if (inclusive) txt('incl.', 6.5, color: muted),
              ],
            ),
            right: true,
          ),
          cell(txt(plain(i.total), 8.5, bold: true), right: true),
        ],
      ));
    }

    return pw.Table(
      border: bordered
          ? pw.TableBorder.all(color: borderColor, width: 0.6)
          : pw.TableBorder(
              bottom: pw.BorderSide(color: borderColor, width: 0.6),
              horizontalInside: pw.BorderSide(color: borderColor, width: 0.3)),
      columnWidths: {
        for (final (n, (_, w, _)) in cols.indexed) n: w,
      },
      children: rows,
    );
  }

  /// Tax lines for the totals block — CGST/SGST halves within the state,
  /// IGST across states. Shows the rate when all items share one.
  List<(String, double)> get taxLines {
    if (inv.gstAmt <= 0) return const [];
    final rates = inv.taxSlabs.map((s) => s.rate).where((r) => r > 0).toSet();
    final single = rates.length == 1 ? rates.first : null;
    if (inv.isInterState) {
      return [('IGST${single != null ? ' @${num0(single)}%' : ''}', inv.gstAmt)];
    }
    final half = single != null ? ' @${num0(single / 2)}%' : '';
    return [('CGST$half', inv.gstAmt / 2), ('SGST$half', inv.gstAmt / 2)];
  }

  /// Totals column. The last row ("Total", or "Balance Due" if something
  /// was paid) is drawn as a highlighted bar.
  pw.Widget totals({
    required PdfColor barBg,
    required PdfColor barFg,
    double width = 230,
    PdfColor textColor = ink,
    PdfColor labelColor = muted,
  }) {
    pw.Widget row(String l, String v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.2, horizontal: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              txt(l, 9, color: bold ? textColor : labelColor, bold: bold),
              txt(v, 9, color: textColor, bold: bold),
            ],
          ),
        );
    pw.Widget bar(String l, String v) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          color: barBg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              txt(l, 10.5, bold: true, color: barFg),
              txt(v, 10.5, bold: true, color: barFg),
            ],
          ),
        );

    final paid = inv.received > 0;
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          row('Sub Total', money(inv.subtotal)),
          for (final (l, v) in taxLines) row(l, money(v)),
          if (inv.otherCharges > 0) row('Other Charges', money(inv.otherCharges)),
          if (inv.discountAmt > 0) row('Discount', '- ${money(inv.discountAmt)}'),
          if (inv.roundOff.abs() >= 0.005)
            row('Round Off',
                '${inv.roundOff > 0 ? '+' : '-'} ${money(inv.roundOff.abs())}'),
          if (!paid) bar('Total', money(inv.roundedTotal)),
          if (paid) ...[
            row('Total', money(inv.roundedTotal), bold: true),
            row(inv.isPaid ? 'Paid (${inv.paymentMode})' : 'Paid', money(inv.received)),
            bar('Balance Due', money(inv.balanceDue)),
          ],
        ],
      ),
    );
  }

  pw.Widget amountInWords({PdfColor color = ink}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          label('Amount in words'),
          pw.SizedBox(height: 2),
          txt(AmountInWords.inr(inv.roundedTotal), 8.5, bold: true, color: color),
        ],
      );

  pw.Widget? upiQr({double size = 62}) {
    final upi = inv.senderUpiId?.trim() ?? '';
    if (upi.isEmpty || inv.balanceDue <= 0) return null;
    final uri = Uri(scheme: 'upi', host: 'pay', queryParameters: {
      'pa': upi,
      'pn': sellerName,
      'am': inv.balanceDue.toStringAsFixed(2),
      'cu': 'INR',
      'tn': 'Invoice ${inv.invoiceNumber}',
    });
    return pw.Column(children: [
      pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: uri.toString(),
        width: size,
        height: size,
        drawText: false,
      ),
      pw.SizedBox(height: 2),
      txt('Scan to pay (UPI)', 6.5, color: muted),
    ]);
  }

  pw.Widget paymentInfo({PdfColor titleColor = ink}) {
    final bank = [
      if (_has(inv.senderBankName)) 'Bank: ${inv.senderBankName}',
      if (_has(inv.senderBankAccountNo)) 'A/c No: ${inv.senderBankAccountNo}',
      if (_has(inv.senderBankIfsc)) 'IFSC: ${inv.senderBankIfsc}',
      if (_has(inv.senderUpiId)) 'UPI: ${inv.senderUpiId}',
    ];
    final qr = upiQr();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              txt('Payment Info', 9.5, bold: true, color: titleColor),
              pw.SizedBox(height: 3),
              txt('Mode: ${inv.paymentMode}', 8.5, color: muted),
              for (final l in bank) txt(l, 8.5, color: muted),
            ],
          ),
        ),
        if (qr != null) ...[pw.SizedBox(width: 8), qr],
      ],
    );
  }

  pw.Widget? notesAndTerms({PdfColor titleColor = ink}) {
    if (!_has(inv.note) && !_has(inv.terms)) return null;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (_has(inv.note)) ...[
          txt('Notes', 9.5, bold: true, color: titleColor),
          pw.SizedBox(height: 2),
          txt(inv.note!, 8.5, color: muted),
          pw.SizedBox(height: 8),
        ],
        if (_has(inv.terms)) ...[
          txt('Terms & Conditions', 9.5, bold: true, color: titleColor),
          pw.SizedBox(height: 2),
          txt(inv.terms!, 8.5, color: muted),
        ],
      ],
    );
  }

  pw.Widget signature({PdfColor color = ink, double width = 170}) {
    final signer = inv.senderSignatory?.trim() ?? '';
    return pw.SizedBox(
      width: width,
      child: pw.Column(
        children: [
          txt('For $sellerName', 8.5, bold: true, color: color,
              align: pw.TextAlign.center),
          pw.SizedBox(
            height: 38,
            child: pw.Center(
              child: signer.isEmpty
                  ? pw.SizedBox()
                  : pw.Text(signer,
                      style: pw.TextStyle(font: script, fontSize: 24, color: color)),
            ),
          ),
          pw.Container(height: 0.7, color: line),
          pw.SizedBox(height: 3),
          txt('Authorised Signatory', 8, color: muted),
        ],
      ),
    );
  }

  static const _sideGroup = {
    InvoiceSection.words,
    InvoiceSection.payment,
    InvoiceSection.totals,
  };

  /// Lays out the body sections in the user's order. Neighbours that read
  /// well together share a row: amount-in-words / payment beside totals,
  /// and notes beside the signature — so the standard order reproduces
  /// each template's designed look, and any custom order still flows.
  ///
  /// [sideBySide] and [single] let a layout restyle those rows (the GST
  /// grid draws them as bordered boxes); the items table is never wrapped.
  List<pw.Widget> composeBody({
    required pw.Widget parties,
    required pw.Widget items,
    required PdfColor barBg,
    required PdfColor barFg,
    PdfColor titleColor = ink,
    double gap = 16,
    double totalsWidth = 230,
    pw.Widget Function(pw.Widget left, pw.Widget right)? sideBySide,
    pw.Widget Function(pw.Widget child)? single,
    pw.Widget? wordsOverride,
    pw.Widget? signatureOverride,
  }) {
    final side = sideBySide ??
        (l, r) => pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [pw.Expanded(child: l), pw.SizedBox(width: 20), r],
            );
    final one = single ?? (w) => w;
    final sig = signatureOverride ??
        signature(color: titleColor == ink ? ink : titleColor);

    pw.Widget? render(InvoiceSection s) => switch (s) {
          InvoiceSection.parties => parties,
          InvoiceSection.items => items,
          InvoiceSection.words => wordsOverride ?? amountInWords(),
          InvoiceSection.payment => paymentInfo(titleColor: titleColor),
          InvoiceSection.totals =>
            totals(barBg: barBg, barFg: barFg, width: totalsWidth),
          InvoiceSection.notes => notesAndTerms(titleColor: titleColor),
          InvoiceSection.signature => sig,
        };

    final order = sections.visible;
    final out = <pw.Widget>[];
    void add(pw.Widget w) {
      if (out.isNotEmpty && gap > 0) out.add(pw.SizedBox(height: gap));
      out.add(w);
    }

    pw.Widget stack(Iterable<pw.Widget> ws) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final (n, w) in ws.indexed) ...[
              if (n > 0) pw.SizedBox(height: 12),
              w,
            ],
          ],
        );

    var i = 0;
    while (i < order.length) {
      final s = order[i];

      if (_sideGroup.contains(s)) {
        var j = i;
        while (j < order.length && _sideGroup.contains(order[j])) {
          j++;
        }
        final run = order.sublist(i, j);
        if (run.contains(InvoiceSection.totals) &&
            (run.length > 1 || _stamped)) {
          final left = [
            for (final x in run)
              if (x != InvoiceSection.totals) render(x),
            if (_stamped) paidStamp(),
          ].whereType<pw.Widget>();
          add(side(stack(left), render(InvoiceSection.totals)!));
        } else {
          for (final x in run) {
            final w = render(x);
            if (w == null) continue;
            add(x == InvoiceSection.totals && single == null
                ? pw.Align(alignment: pw.Alignment.centerRight, child: w)
                : one(w));
          }
        }
        i = j;
        continue;
      }

      final next = i + 1 < order.length ? order[i + 1] : null;
      final isPair = (s == InvoiceSection.notes && next == InvoiceSection.signature) ||
          (s == InvoiceSection.signature && next == InvoiceSection.notes);
      if (isPair) {
        add(side(render(InvoiceSection.notes) ?? pw.SizedBox(), sig));
        i += 2;
        continue;
      }

      final w = render(s);
      if (w != null) {
        if (s == InvoiceSection.items) {
          add(w);
        } else if (s == InvoiceSection.signature && single == null) {
          add(pw.Align(alignment: pw.Alignment.centerRight, child: w));
        } else {
          add(one(w));
        }
      }
      i++;
    }
    return out;
  }

  pw.Widget footer(pw.Context ctx,
          {PdfColor color = muted,
          pw.Alignment alignment = pw.Alignment.centerRight}) =>
      pw.Container(
        alignment: alignment,
        margin: const pw.EdgeInsets.only(top: 8),
        child: txt(
            ctx.pagesCount > 1
                ? 'Page ${ctx.pageNumber} of ${ctx.pagesCount}'
                : 'This is a computer generated invoice.',
            7,
            color: color),
      );

  pw.PageTheme pageTheme({
    pw.EdgeInsets margin = const pw.EdgeInsets.all(36),
    pw.Widget Function(pw.Context)? background,
  }) =>
      pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: margin,
        buildBackground: background,
      );

  bool get _stamped => inv.isPaid && inv.showPaidStamp;

  /// Rotated "PAID" rubber stamp, laid out beside the totals so it never
  /// covers other content whatever the template or section order.
  pw.Widget paidStamp() {
    const green = PdfColor.fromInt(0xFF16A34A);
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: pw.Opacity(
        opacity: 0.75,
        child: pw.Transform.rotate(
          angle: 0.22,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: green, width: 2.5),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Column(children: [
              txt('PAID', 28, bold: true, color: green, spacing: 5),
              txt('VIA ${inv.paymentMode.toUpperCase()}', 7,
                  bold: true, color: green, spacing: 1.5),
            ]),
          ),
        ),
      ),
    );
  }

  /// Paints [painter] over the whole page (ignoring margins), page 1 only
  /// unless [everyPage].
  pw.Widget Function(pw.Context) paintPage(
          void Function(PdfGraphics c, double w, double h) painter,
          {bool everyPage = false}) =>
      (ctx) {
        if (!everyPage && ctx.pageNumber != 1) return pw.SizedBox();
        final f = PdfPageFormat.a4;
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.CustomPaint(
            size: PdfPoint(f.width, f.height),
            painter: (c, size) => painter(c, size.x, size.y),
          ),
        );
      };

  static void poly(PdfGraphics c, PdfColor color, List<List<double>> pts) {
    c.setFillColor(color);
    c.moveTo(pts.first[0], pts.first[1]);
    for (final p in pts.skip(1)) {
      c.lineTo(p[0], p[1]);
    }
    c.closePath();
    c.fillPath();
  }

  static PdfColor shade(PdfColor c, double f) => PdfColor(
      (c.red * f).clamp(0, 1), (c.green * f).clamp(0, 1), (c.blue * f).clamp(0, 1));

  static PdfColor lighten(PdfColor c, double f) => PdfColor(
      c.red + (1 - c.red) * f, c.green + (1 - c.green) * f, c.blue + (1 - c.blue) * f);

  // ═════════════════════════════════════════════════════════════════════════
  // Layouts
  // ═════════════════════════════════════════════════════════════════════════

  /// Big INVOICE title, FROM / BILL TO columns, accent table header.
  pw.MultiPage simple() {
    final stripe = lighten(accent, 0.92);
    return pw.MultiPage(
      pageTheme: pageTheme(),
      footer: footer,
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  txt('INVOICE', 30, bold: true, color: accent, spacing: 1.5),
                  if (_has(inv.senderGst))
                    txt('TAX INVOICE  ·  ORIGINAL FOR RECIPIENT', 7.5,
                        color: muted, spacing: 0.5),
                ],
              ),
            ),
            metaTable(),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 1, color: line),
        pw.SizedBox(height: 14),
        ...composeBody(
          parties: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: party('From', sellerName, sellerLines)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: party('Bill To', inv.clientName, buyerLines)),
            ],
          ),
          items: itemsTable(headerBg: accent, headerFg: onAccent, stripe: stripe),
          barBg: accent,
          barFg: onAccent,
        ),
      ],
    );
  }

  /// Logo + seller top-left, colored INVOICE title top-right, tinted
  /// bill-to strip.
  pw.MultiPage logoHeader() {
    final band = lighten(accent, 0.9);
    return pw.MultiPage(
      pageTheme: pageTheme(),
      footer: footer,
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logoBox(54),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  txt(sellerName, 14, bold: true),
                  for (final l in sellerLines) txt(l, 8.5, color: muted),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                txt('INVOICE', 28, bold: true, color: accent, spacing: 1.2),
                txt(inv.invoiceNumber, 10, color: muted),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        ...composeBody(
          parties: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: band, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: party('Bill To', inv.clientName, buyerLines)),
                pw.SizedBox(width: 16),
                metaTable(),
              ],
            ),
          ),
          items: itemsTable(headerBg: accent, headerFg: onAccent, stripe: band),
          barBg: accent,
          barFg: onAccent,
          titleColor: accent,
        ),
      ],
    );
  }

  pw.Widget _billToAndMeta({PdfColor? titleColor}) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
              child: party('Bill To', inv.clientName, buyerLines,
                  titleColor: titleColor)),
          pw.SizedBox(width: 20),
          metaTable(),
        ],
      );

  /// Solid color band across the top of page 1.
  pw.MultiPage banner() {
    const bandH = 140.0;
    final stripe = lighten(accent, 0.92);
    return pw.MultiPage(
      pageTheme: pageTheme(
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        background: paintPage((c, w, h) {
          poly(c, accent, [[0, h], [w, h], [w, h - bandH], [0, h - bandH]]);
          poly(c, shade(accent, 0.75),
              [[w - 170, h - bandH], [w, h - bandH], [w, h - bandH - 6], [w - 164, h - bandH - 6]]);
          poly(c, accent, [[0, 0], [w, 0], [w, 8], [0, 8]]);
        }),
      ),
      footer: footer,
      build: (ctx) => [
        pw.SizedBox(
          height: bandH - 30,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              logoBox(52, bg: PdfColors.white, fg: accent),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    txt(sellerName, 14, bold: true, color: onAccent),
                    for (final l in sellerLines)
                      txt(l, 7.5, color: onAccent),
                  ],
                ),
              ),
              txt('INVOICE', 32, bold: true, color: onAccent, spacing: 2),
            ],
          ),
        ),
        pw.SizedBox(height: 22),
        ...composeBody(
          parties: _billToAndMeta(),
          items: itemsTable(headerBg: accent, headerFg: onAccent, stripe: stripe),
          barBg: accent,
          barFg: onAccent,
        ),
      ],
    );
  }

  /// Arrow-shaped color tag holding the INVOICE title.
  pw.MultiPage ribbon() {
    final stripe = lighten(accent, 0.9);
    final tag = pw.CustomPaint(
      size: const PdfPoint(200, 50),
      painter: (c, size) => poly(c, accent, [
        [22, 0], [size.x, 0], [size.x, size.y], [22, size.y], [0, size.y / 2],
      ]),
      child: pw.SizedBox(
        width: 200,
        height: 50,
        child: pw.Center(
            child: txt('INVOICE', 24, bold: true, color: onAccent, spacing: 1.5)),
      ),
    );
    // The page has no right margin so the tag can bleed off the edge;
    // everything else gets it back as padding.
    pw.Widget pad(pw.Widget w) =>
        pw.Padding(padding: const pw.EdgeInsets.only(right: 36), child: w);
    return pw.MultiPage(
      pageTheme: pageTheme(
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 0, 36),
      ),
      footer: (ctx) => pad(footer(ctx)),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logoBox(50),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('From'),
                  txt(sellerName, 13, bold: true),
                  for (final l in sellerLines) txt(l, 8.5, color: muted),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            tag,
          ],
        ),
        pw.SizedBox(height: 20),
        for (final w in composeBody(
          parties: _billToAndMeta(),
          items: itemsTable(headerBg: accent, headerFg: onAccent, stripe: stripe),
          barBg: accent,
          barFg: onAccent,
        ))
          pad(w),
      ],
    );
  }

  /// Bordered GST tax-invoice grid, the way Indian traders print them.
  pw.MultiPage gstClassic() {
    final border = pw.Border.all(color: accent, width: 0.8);
    final headTint = lighten(accent, 0.88);

    pw.Widget box(pw.Widget child) => pw.SizedBox(
          width: double.infinity,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(border: border),
            child: child,
          ),
        );

    // Two bordered boxes side by side at equal height — a one-row table,
    // since a stretched Row can't be laid out inside a MultiPage.
    pw.Widget pair(pw.Widget left, pw.Widget right) => pw.Table(
          border: pw.TableBorder.all(color: accent, width: 0.8),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(7), child: left),
              pw.Padding(padding: const pw.EdgeInsets.all(7), child: right),
            ]),
          ],
        );

    // Per-rate tax summary.
    final inter = inv.isInterState;
    final slabHeaders = [
      'GST Rate', 'Taxable Value',
      if (!inter) ...['CGST', 'SGST'] else 'IGST',
      'Total Tax',
    ];
    final slabTable = pw.Table(
      border: pw.TableBorder.all(color: accent, width: 0.6),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headTint),
          children: [
            for (final h in slabHeaders)
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: txt(h, 7.5, bold: true, align: pw.TextAlign.center),
              ),
          ],
        ),
        for (final sl in inv.taxSlabs)
          pw.TableRow(children: [
            for (final v in [
              '${num0(sl.rate)}%',
              plain(sl.taxable),
              if (!inter) ...[plain(sl.tax / 2), plain(sl.tax / 2)] else plain(sl.tax),
              plain(sl.tax),
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: txt(v, 8, align: pw.TextAlign.right),
              ),
          ]),
      ],
    );

    return pw.MultiPage(
      pageTheme: pageTheme(margin: const pw.EdgeInsets.all(28)),
      footer: footer,
      build: (ctx) => [
        pw.Row(
          children: [
            pw.Expanded(child: pw.SizedBox()),
            txt(_has(inv.senderGst) ? 'TAX INVOICE' : 'INVOICE', 15,
                bold: true, color: accent, spacing: 1.5),
            pw.Expanded(
              child: txt('ORIGINAL FOR RECIPIENT', 7,
                  color: muted, align: pw.TextAlign.right),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        // Seller | invoice meta
        pair(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[logoBox(44), pw.SizedBox(width: 8)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    txt(sellerName, 13, bold: true, color: accent),
                    for (final l in sellerLines) txt(l, 8),
                  ],
                ),
              ),
            ],
          ),
          metaTable(labelColor: ink),
        ),
        ...composeBody(
          parties: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              txt('Bill To:', 8, bold: true, color: accent),
              txt(inv.clientName.isEmpty ? '—' : inv.clientName, 11, bold: true),
              for (final l in buyerLines) txt(l, 8),
            ],
          ),
          items: itemsTable(
              headerBg: headTint, headerFg: ink, bordered: true, borderColor: accent),
          barBg: accent,
          barFg: onAccent,
          gap: 0,
          totalsWidth: 190,
          sideBySide: pair,
          single: box,
          wordsOverride: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [amountInWords(), pw.SizedBox(height: 8), slabTable],
          ),
          signatureOverride: pw.Column(
            children: [
              signature(width: 180),
              pw.SizedBox(height: 22),
              pw.Container(height: 0.7, color: line),
              pw.SizedBox(height: 3),
              txt("Receiver's Signature", 8, color: muted),
            ],
          ),
        ),
      ],
    );
  }

  /// Parallelogram color blocks in the top-left and bottom-right corners.
  pw.MultiPage diagonal() {
    const titleH = 92.0;
    final dark = shade(accent, 0.6);
    return pw.MultiPage(
      pageTheme: pageTheme(
        margin: const pw.EdgeInsets.fromLTRB(36, 26, 36, 40),
        background: (ctx) {
          final f = PdfPageFormat.a4;
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.CustomPaint(
              size: PdfPoint(f.width, f.height),
              painter: (c, size) {
                final w = size.x, h = size.y;
                if (ctx.pageNumber == 1) {
                  poly(c, accent, [[0, h], [290, h], [235, h - titleH], [0, h - titleH]]);
                  poly(c, dark, [[290, h], [312, h], [257, h - titleH], [235, h - titleH]]);
                }
                poly(c, const PdfColor.fromInt(0xFFE6E8EC),
                    [[w, 0], [w, 120], [w - 70, 120], [w - 250, 0]]);
                poly(c, accent, [[w, 0], [w, 60], [w - 110, 60], [w - 150, 0]]);
              },
            ),
          );
        },
      ),
      // Left-aligned so it stays clear of the bottom-right corner art.
      footer: (ctx) => footer(ctx, alignment: pw.Alignment.centerLeft),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title stays vertically centered in the color band; the meta
            // column may grow past it.
            pw.SizedBox(
              width: 190,
              height: titleH - 26,
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: txt('INVOICE', 30, bold: true, color: onAccent, spacing: 2),
              ),
            ),
            pw.Spacer(),
            metaTable(),
          ],
        ),
        pw.SizedBox(height: 22),
        ...composeBody(
          parties: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              logoBox(46),
              pw.SizedBox(width: 10),
              pw.Expanded(
                  child: party('From', sellerName, sellerLines, titleColor: accent)),
              pw.SizedBox(width: 20),
              pw.Expanded(
                  child: party('Bill To', inv.clientName, buyerLines,
                      titleColor: accent)),
            ],
          ),
          items: itemsTable(
              headerBg: PdfColors.black, headerFg: PdfColors.white, stripe: zebra),
          barBg: PdfColors.black,
          barFg: PdfColors.white,
        ),
        pw.SizedBox(height: 50), // keep clear of the corner art
      ],
    );
  }

  /// Dark page with the invoice laid out on a white rounded card.
  pw.MultiPage darkCard() {
    const headH = 150.0;
    final band = lighten(accent, 0.9);
    return pw.MultiPage(
      pageTheme: pageTheme(
        margin: const pw.EdgeInsets.fromLTRB(42, 24, 42, 44),
        background: paintPage((c, w, h) {
          poly(c, accent, [[0, 0], [w, 0], [w, h], [0, h]]);
          poly(c, shade(accent, 0.8), [[0, 0], [0, 210], [230, 0]]);
          c.setFillColor(PdfColors.white);
          c.drawRRect(20, 26, w - 40, h - headH - 44, 14, 14);
          c.fillPath();
        }),
      ),
      footer: footer,
      header: (ctx) => ctx.pageNumber != 1
          ? pw.SizedBox()
          : pw.SizedBox(
              height: headH - 10,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  logoBox(52, bg: PdfColors.white, fg: accent),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        label('From', color: PdfColors.grey300),
                        txt(sellerName, 13, bold: true, color: PdfColors.white),
                        for (final l in sellerLines)
                          txt(l, 8, color: PdfColors.grey200),
                      ],
                    ),
                  ),
                  txt('INVOICE', 30, bold: true, color: PdfColors.white, spacing: 2),
                ],
              ),
            ),
      build: (ctx) => [
        pw.SizedBox(height: 18),
        ...composeBody(
          parties: _billToAndMeta(titleColor: accent),
          items: itemsTable(headerBg: band, headerFg: accent, stripe: zebra),
          barBg: accent,
          barFg: PdfColors.white,
          titleColor: accent,
        ),
      ],
    );
  }
}

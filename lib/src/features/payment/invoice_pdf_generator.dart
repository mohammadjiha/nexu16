import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'commission_invoice_model.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
const _primaryBlue = PdfColor.fromInt(0xFF0A84FF);
const _darkBg     = PdfColor.fromInt(0xFF1C2340);
const _lightGrey  = PdfColor.fromInt(0xFFF5F7FA);
const _midGrey    = PdfColor.fromInt(0xFFB0B8C8);
const _textDark   = PdfColor.fromInt(0xFF1A1A2E);
const _green      = PdfColor.fromInt(0xFF34C759);
const _accentCyan = PdfColor.fromInt(0xFF00C6FF);

Future<void> printCommissionInvoice(CommissionInvoice invoice) async {
  final doc = pw.Document();

  // Fonts
  final regular   = await PdfGoogleFonts.robotoRegular();
  final medium    = await PdfGoogleFonts.robotoMedium();
  final bold      = await PdfGoogleFonts.robotoBold();
  final extraBold = await PdfGoogleFonts.robotoBlack();

  final dateFmt = DateFormat('dd MMM yyyy');
  final timeFmt = DateFormat('HH:mm');

  String fmtDate(DateTime d) => dateFmt.format(d);
  String fmtTime(DateTime d) => timeFmt.format(d);

  // Payment method display
  final paidByStripe = invoice.status == 'paid';
  final paymentMethod = paidByStripe
      ? 'Stripe (Card)'
      : 'Platform Credit';

  // Total paid
  final totalPaidJod = invoice.commissionJod;
  final stripeUsd = invoice.stripeAmount / 100.0;

  // Operation type display
  final operationDisplay = invoice.operationLabel;

  // Subscription total
  final subscriptionTotal = invoice.monthlyPrice * invoice.months;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Top header bar ─────────────────────────────────────────────
            pw.Container(
              color: _darkBg,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 40, vertical: 28),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: brand
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NEXUS',
                          style: pw.TextStyle(
                              font: extraBold,
                              fontSize: 30,
                              color: _accentCyan,
                              letterSpacing: 4)),
                      pw.Text('Platform',
                          style: pw.TextStyle(
                              font: medium,
                              fontSize: 11,
                              color: const PdfColor(1, 1, 1, 0.7),
                              letterSpacing: 2)),
                    ],
                  ),
                  // Right: INVOICE label + number
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              font: extraBold,
                              fontSize: 22,
                              color: PdfColors.white,
                              letterSpacing: 3)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.invoiceNumber,
                          style: pw.TextStyle(
                              font: medium,
                              fontSize: 11,
                              color: _accentCyan)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                          '${fmtDate(invoice.createdAt)}  ${fmtTime(invoice.createdAt)}',
                          style: pw.TextStyle(
                              font: regular,
                              fontSize: 9,
                              color: const PdfColor(1, 1, 1, 0.6))),
                    ],
                  ),
                ],
              ),
            ),

            // ── Status ribbon ──────────────────────────────────────────────
            pw.Container(
              color: paidByStripe ? _primaryBlue : _green,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 40, vertical: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    paidByStripe ? '✓  PAID VIA STRIPE' : '✓  PAID VIA CREDIT',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: PdfColors.white),
                  ),
                  pw.Text(
                    'Status: ${invoice.status.toUpperCase().replaceAll('_', ' ')}',
                    style: pw.TextStyle(
                        font: medium,
                        fontSize: 9,
                        color: const PdfColor(1, 1, 1, 0.8)),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // ── From / To section ──────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // FROM
                  pw.Expanded(
                    child: _infoBlock(
                      title: 'FROM',
                      lines: [
                        'NEXUS Platform',
                        'nexusplatform.io',
                        'Commission Invoice',
                      ],
                      regular: regular,
                      bold: bold,
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // BILLED TO
                  pw.Expanded(
                    child: _infoBlock(
                      title: 'BILLED TO',
                      lines: [
                        invoice.gymName.isEmpty
                            ? 'Gym ID: ${invoice.gymId}'
                            : invoice.gymName,
                        if (invoice.paidByName.isNotEmpty) invoice.paidByName,
                        'Role: ${invoice.paidByRole.toUpperCase()}',
                      ],
                      regular: regular,
                      bold: bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // ── Operation details table ────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Table header
                  pw.Container(
                    color: _textDark,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: pw.Row(
                      children: [
                        _headerCell('DESCRIPTION', flex: 3, bold: bold),
                        _headerCell('PLAYER', flex: 2, bold: bold),
                        _headerCell('MONTHS', flex: 1, bold: bold,
                            align: pw.TextAlign.center),
                        _headerCell('MONTHLY', flex: 2, bold: bold,
                            align: pw.TextAlign.right),
                        _headerCell('SUB. TOTAL', flex: 2, bold: bold,
                            align: pw.TextAlign.right),
                      ],
                    ),
                  ),
                  // Table row
                  pw.Container(
                    color: _lightGrey,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: pw.Row(
                      children: [
                        _dataCell(operationDisplay, flex: 3,
                            font: medium, color: _textDark),
                        _dataCell(invoice.playerName.isEmpty
                            ? '—' : invoice.playerName,
                            flex: 2, font: regular),
                        _dataCell(invoice.months > 0
                            ? '${invoice.months}' : '—',
                            flex: 1, font: regular,
                            align: pw.TextAlign.center),
                        _dataCell(invoice.monthlyPrice > 0
                            ? '${invoice.monthlyPrice.toStringAsFixed(2)} JOD'
                            : '—',
                            flex: 2, font: regular,
                            align: pw.TextAlign.right),
                        _dataCell(subscriptionTotal > 0
                            ? '${subscriptionTotal.toStringAsFixed(2)} JOD'
                            : '—',
                            flex: 2, font: medium,
                            align: pw.TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // ── Commission breakdown ───────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Notes
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(14),
                      decoration: const pw.BoxDecoration(
                        color: _lightGrey,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAYMENT METHOD',
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 9,
                                  color: _midGrey,
                                  letterSpacing: 1)),
                          pw.SizedBox(height: 4),
                          pw.Text(paymentMethod,
                              style: pw.TextStyle(
                                  font: medium,
                                  fontSize: 11,
                                  color: _textDark)),
                          if (paidByStripe && invoice.paymentIntentId.isNotEmpty &&
                              invoice.paymentIntentId != 'CREDIT') ...[
                            pw.SizedBox(height: 8),
                            pw.Text('TRANSACTION ID',
                                style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 9,
                                    color: _midGrey,
                                    letterSpacing: 1)),
                            pw.SizedBox(height: 4),
                            pw.Text(invoice.paymentIntentId,
                                style: pw.TextStyle(
                                    font: regular,
                                    fontSize: 8,
                                    color: _textDark)),
                            pw.SizedBox(height: 8),
                            pw.Text('CHARGED IN USD',
                                style: pw.TextStyle(
                                    font: bold,
                                    fontSize: 9,
                                    color: _midGrey,
                                    letterSpacing: 1)),
                            pw.SizedBox(height: 4),
                            pw.Text('\$${stripeUsd.toStringAsFixed(2)} USD',
                                style: pw.TextStyle(
                                    font: medium,
                                    fontSize: 11,
                                    color: _textDark)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Totals
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        if (invoice.months > 0) ...[
                          _summaryRow('Commission Rate',
                              '${(invoice.rate * 100).toStringAsFixed(0)}%',
                              regular: regular, medium: medium),
                          _divider(),
                        ],
                        if (invoice.creditUsed > 0) ...[
                          _summaryRow('Credit Applied',
                              '- ${invoice.creditUsed.toStringAsFixed(3)} JOD',
                              regular: regular, medium: medium,
                              valueColor: _green),
                          _divider(),
                        ],
                        if (paidByStripe && stripeUsd > 0) ...[
                          _summaryRow('Charged via Stripe',
                              '\$${stripeUsd.toStringAsFixed(2)} USD',
                              regular: regular, medium: medium),
                          _divider(),
                        ],
                        // Total commission
                        pw.Container(
                          color: _darkBg,
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL COMMISSION',
                                  style: pw.TextStyle(
                                      font: bold,
                                      fontSize: 10,
                                      color: PdfColors.white)),
                              pw.Text(
                                  '${totalPaidJod.toStringAsFixed(3)} JOD',
                                  style: pw.TextStyle(
                                      font: extraBold,
                                      fontSize: 14,
                                      color: _accentCyan)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // ── Footer ─────────────────────────────────────────────────────
            pw.Container(
              color: _lightGrey,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 40, vertical: 14),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NEXUS Platform — nexusplatform.io',
                      style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          color: _midGrey)),
                  pw.Text(
                      'Generated ${fmtDate(DateTime.now())}',
                      style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          color: _midGrey)),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

pw.Widget _infoBlock({
  required String title,
  required List<String> lines,
  required pw.Font regular,
  required pw.Font bold,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title,
          style: pw.TextStyle(
              font: bold,
              fontSize: 9,
              color: _midGrey,
              letterSpacing: 1.5)),
      pw.SizedBox(height: 6),
      ...lines.map((l) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(l,
                style: pw.TextStyle(
                    font: regular, fontSize: 11, color: _textDark)),
          )),
    ],
  );
}

pw.Widget _headerCell(String text,
    {required int flex,
    required pw.Font bold,
    pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Text(text,
        style: pw.TextStyle(
            font: bold, fontSize: 8, color: PdfColors.white, letterSpacing: 0.5),
        textAlign: align),
  );
}

pw.Widget _dataCell(String text,
    {required int flex,
    required pw.Font font,
    PdfColor color = _textDark,
    pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Text(text,
        style: pw.TextStyle(font: font, fontSize: 10, color: color),
        textAlign: align),
  );
}

pw.Widget _summaryRow(String label, String value,
    {required pw.Font regular,
    required pw.Font medium,
    PdfColor valueColor = _textDark}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style:
                pw.TextStyle(font: regular, fontSize: 10, color: _midGrey)),
        pw.Text(value,
            style: pw.TextStyle(
                font: medium, fontSize: 10, color: valueColor)),
      ],
    ),
  );
}

pw.Widget _divider() {
  return pw.Divider(color: PdfColors.grey300, height: 1, thickness: 0.5);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';

import '../../../user/models/user_model.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final archivedPlayersProvider =
    StreamProvider.family<List<_ArchivedPlayer>, String>((ref, gymId) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('gymId', isEqualTo: gymId)
      .where('role', isEqualTo: 'player')
      .snapshots()
      .map((snap) {
    final now = DateTime.now();
    final list = <_ArchivedPlayer>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      data['uid'] = doc.id;
      final isDeleted = data['deleted'] == true;
      DateTime? subEnd;
      final raw = data['subscriptionEnd'];
      if (raw is Timestamp) subEnd = raw.toDate();

      final isExpired = !isDeleted &&
          subEnd != null &&
          subEnd.isBefore(now);

      if (isDeleted || isExpired) {
        list.add(_ArchivedPlayer(
          model: UserModel.fromMap(data),
          isDeleted: isDeleted,
          isExpired: isExpired,
        ));
      }
    }
    // Sort: deleted first, then by subscription end date desc
    list.sort((a, b) {
      if (a.isDeleted && !b.isDeleted) return -1;
      if (!a.isDeleted && b.isDeleted) return 1;
      final aEnd = a.model.subscriptionEnd;
      final bEnd = b.model.subscriptionEnd;
      if (aEnd == null && bEnd == null) return 0;
      if (aEnd == null) return 1;
      if (bEnd == null) return -1;
      return bEnd.compareTo(aEnd);
    });
    return list;
  });
});

class _ArchivedPlayer {
  final UserModel model;
  final bool isDeleted;
  final bool isExpired;
  _ArchivedPlayer({
    required this.model,
    required this.isDeleted,
    required this.isExpired,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class ArchivedPlayersScreen extends ConsumerStatefulWidget {
  final String gymId;
  final String gymName;

  const ArchivedPlayersScreen({
    super.key,
    required this.gymId,
    required this.gymName,
  });

  @override
  ConsumerState<ArchivedPlayersScreen> createState() =>
      _ArchivedPlayersScreenState();
}

class _ArchivedPlayersScreenState
    extends ConsumerState<ArchivedPlayersScreen> {
  String _filter = 'all'; // 'all' | 'deleted' | 'expired'
  String _search = '';

  static const _bg = Color(0xFF1C1C1E);
  static const _card = Color(0xFF2C2C2E);
  static const _accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(archivedPlayersProvider(widget.gymId));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text('الأرشيف',
            style: TextStyle(
                fontSize: 16.sp, fontWeight: FontWeight.bold)),
        actions: [
          async.whenData((list) => list).value != null
              ? IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: _accent),
                  tooltip: 'طباعة PDF',
                  onPressed: () => _printPdf(async.value!),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildSearch(),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _accent)),
              error: (e, _) =>
                  Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
              data: (list) {
                final filtered = _applyFilter(list);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد لاعبون في الأرشيف',
                        style: TextStyle(color: Colors.white54)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildCard(filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _chip('الكل', 'all'),
          const SizedBox(width: 8),
          _chip('محذوف', 'deleted'),
          const SizedBox(width: 8),
          _chip('منتهي الاشتراك', 'expired'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _accent : _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15.sp,
            )),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'بحث باسم أو إيميل...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
    );
  }

  List<_ArchivedPlayer> _applyFilter(List<_ArchivedPlayer> list) {
    var result = list;
    if (_filter == 'deleted') result = result.where((p) => p.isDeleted).toList();
    if (_filter == 'expired') result = result.where((p) => p.isExpired).toList();
    if (_search.isNotEmpty) {
      result = result.where((p) {
        final name =
            '${p.model.firstName ?? ''} ${p.model.lastName ?? ''}'.toLowerCase();
        return name.contains(_search) ||
            (p.model.email.toLowerCase().contains(_search));
      }).toList();
    }
    return result;
  }

  Widget _buildCard(_ArchivedPlayer p) {
    final m = p.model;
    final name =
        '${m.firstName ?? ''} ${m.lastName ?? ''}'.trim().isEmpty
            ? m.email
            : '${m.firstName ?? ''} ${m.lastName ?? ''}'.trim();
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.isDeleted
              ? Colors.red.withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isDeleted
                      ? Colors.red.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.isDeleted ? 'محذوف' : 'منتهي الاشتراك',
                  style: TextStyle(
                    color: p.isDeleted ? Colors.red : Colors.orange,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(name,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _row('الإيميل', m.email),
          if (m.phone != null) _row('الهاتف', m.phone!),
          if (m.subscriptionPlan != null)
            _row('الخطة', m.subscriptionPlan!),
          if (m.subscriptionStart != null)
            _row('بداية الاشتراك', fmt.format(m.subscriptionStart!)),
          if (m.subscriptionEnd != null)
            _row('نهاية الاشتراك', fmt.format(m.subscriptionEnd!)),
          _row('الإجمالي', '${m.totalAmount?.toStringAsFixed(2) ?? 0} د.أ'),
          _row('المدفوع', '${m.amountPaid?.toStringAsFixed(2) ?? 0} د.أ'),
          if ((m.amountRemaining ?? 0) > 0)
            _row('المتبقي',
                '${m.amountRemaining?.toStringAsFixed(2)} د.أ',
                valueColor: Colors.red),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white70,
                  fontSize: 14.sp)),
          Text(label,
              style: TextStyle(
                  color: Colors.white38, fontSize: 14.sp)),
        ],
      ),
    );
  }

  // ── PDF Export ──────────────────────────────────────────────────────────────
  Future<void> _printPdf(List<_ArchivedPlayer> list) async {
    final filtered = _applyFilter(list);
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();
    final fmt = DateFormat('dd/MM/yyyy');
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pw.Widget arTxt(String text,
        {double size = 10,
        bool bold = false,
        PdfColor color = PdfColors.black,
        pw.TextAlign align = pw.TextAlign.right}) =>
        pw.Text(text,
            style: pw.TextStyle(
              font: bold ? arabicFontBold : arabicFont,
              fontSize: size,
              color: color,
            ),
            textDirection: pw.TextDirection.rtl,
            textAlign: align);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                arTxt(now, size: 9, color: const PdfColor(1, 1, 1, 0.7)),
                arTxt('أرشيف اللاعبين — ${widget.gymName}',
                    size: 14, bold: true, color: PdfColors.white),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Summary row
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Row(
              children: [
                _pdfStat('إجمالي', '${filtered.length}', arabicFont, arabicFontBold),
                pw.SizedBox(width: 12),
                _pdfStat('محذوف',
                    '${filtered.where((p) => p.isDeleted).length}',
                    arabicFont, arabicFontBold,
                    color: PdfColors.red),
                pw.SizedBox(width: 12),
                _pdfStat('منتهي',
                    '${filtered.where((p) => p.isExpired).length}',
                    arabicFont, arabicFontBold,
                    color: PdfColors.orange),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Table
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              headers: [
                'الحالة', 'الاسم', 'الإيميل', 'الهاتف',
                'الخطة', 'بداية الاشتراك', 'نهاية الاشتراك',
                'الإجمالي', 'المدفوع', 'المتبقي'
              ],
              data: filtered.map((p) {
                final m = p.model;
                final name =
                    '${m.firstName ?? ''} ${m.lastName ?? ''}'.trim();
                return [
                  p.isDeleted ? 'محذوف' : 'منتهي',
                  name.isEmpty ? m.email : name,
                  m.email,
                  m.phone ?? '-',
                  m.subscriptionPlan ?? '-',
                  m.subscriptionStart != null
                      ? fmt.format(m.subscriptionStart!)
                      : '-',
                  m.subscriptionEnd != null
                      ? fmt.format(m.subscriptionEnd!)
                      : '-',
                  '${m.totalAmount?.toStringAsFixed(2) ?? 0}',
                  '${m.amountPaid?.toStringAsFixed(2) ?? 0}',
                  '${m.amountRemaining?.toStringAsFixed(2) ?? 0}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  font: arabicFontBold,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellStyle:
                  pw.TextStyle(font: arabicFont, fontSize: 7.5),
              cellAlignment: pw.Alignment.centerRight,
              rowDecoration: const pw.BoxDecoration(),
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (_) async => doc.save());
  }

  pw.Widget _pdfStat(String label, String value,
      pw.Font font, pw.Font bold,
      {PdfColor color = PdfColors.blueGrey800}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  font: bold, fontSize: 16, color: color),
              textDirection: pw.TextDirection.rtl),
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl),
        ],
      ),
    );
  }
}

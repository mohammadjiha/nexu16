import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import 'commission_invoice_model.dart';
import 'invoice_pdf_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Invoice history screen for Admin & Coach — reads from
/// `users/{uid}/commissionInvoices` sorted by date desc.
// ─────────────────────────────────────────────────────────────────────────────
class CommissionHistoryScreen extends StatefulWidget {
  final String title;

  const CommissionHistoryScreen({
    super.key,
    this.title = 'Invoice History',
  });

  @override
  State<CommissionHistoryScreen> createState() =>
      _CommissionHistoryScreenState();
}

class _CommissionHistoryScreenState
    extends State<CommissionHistoryScreen> {
  static const _bg    = Color(0xFF1C1C1E);
  static const _card  = Color(0xFF2C2C2E);
  static const _cyan  = Color(0xFF00E5FF);

  String _filter = 'all'; // 'all' | 'stripe' | 'credit'
  String _search = '';

  Stream<List<CommissionInvoice>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('commissionInvoices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CommissionInvoice.fromMap(d.id, d.data()))
            .toList());
  }

  List<CommissionInvoice> _applyFilter(List<CommissionInvoice> all) {
    var list = all;
    if (_filter == 'stripe') {
      list = list.where((i) => i.status == 'paid').toList();
    } else if (_filter == 'credit') {
      list = list.where((i) => i.status == 'paid_by_credit').toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((i) =>
          i.invoiceNumber.toLowerCase().contains(q) ||
          i.playerName.toLowerCase().contains(q) ||
          i.operationLabel.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: TextStyle(
                fontSize: 15.sp, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFilterRow(),
        ),
      ),
      body: Column(
        children: [
          _buildSearch(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _chip('All', 'all'),
          const SizedBox(width: 8),
          _chip('Stripe', 'stripe'),
          const SizedBox(width: 8),
          _chip('Credit', 'credit'),
        ],
      ),
    );
  }

  Widget _chip(String label, String val) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _cyan : _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: sel ? Colors.black : Colors.white70,
              fontWeight:
                  sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 11.sp,
            )),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search invoice # or player…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<CommissionInvoice>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _cyan));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        final all = snap.data ?? [];
        final filtered = _applyFilter(all);

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long,
                    color: Colors.white24, size: 56),
                const SizedBox(height: 12),
                Text('No invoices found',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 13.sp)),
              ],
            ),
          );
        }

        // Summary row
        final totalJod = filtered.fold<double>(
            0, (s, i) => s + i.commissionJod);

        return Column(
          children: [
            _buildSummaryBanner(filtered.length, totalJod),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _buildCard(filtered[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBanner(int count, double totalJod) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$count invoice${count == 1 ? '' : 's'}',
              style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
          Text('Total: ${totalJod.toStringAsFixed(3)} JOD',
              style: TextStyle(
                  color: _cyan,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard(CommissionInvoice inv) {
    final byCredit = inv.paidByCredit;
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(inv.createdAt);
    final statusColor = byCredit ? Colors.green : Colors.blue;
    final statusLabel = byCredit ? 'CREDIT' : 'STRIPE';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold)),
                ),
                // Invoice number
                Text(inv.invoiceNumber,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.sp,
                        fontFamily: 'monospace')),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(inv.operationLabel,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold)),
                    Text('${inv.commissionJod.toStringAsFixed(3)} JOD',
                        style: TextStyle(
                            color: _cyan,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                if (inv.playerName.isNotEmpty)
                  _row(Icons.person_outline,
                      inv.playerName, Colors.white60),
                if (inv.gymName.isNotEmpty)
                  _row(Icons.sports_gymnastics,
                      inv.gymName, Colors.white60),
                if (inv.months > 0)
                  _row(Icons.calendar_today_outlined,
                      '${inv.months} month${inv.months > 1 ? 's' : ''}'
                      ' × ${inv.monthlyPrice.toStringAsFixed(2)} JOD',
                      Colors.white54),
                if (inv.creditUsed > 0)
                  _row(Icons.account_balance_wallet_outlined,
                      'Credit used: ${inv.creditUsed.toStringAsFixed(3)} JOD',
                      Colors.greenAccent.withOpacity(0.8)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr,
                        style: TextStyle(
                            color: Colors.white38, fontSize: 9.sp)),
                    TextButton.icon(
                      onPressed: () => printCommissionInvoice(inv),
                      icon: const Icon(Icons.picture_as_pdf,
                          color: _cyan, size: 16),
                      label: Text('Print',
                          style: TextStyle(
                              color: _cyan, fontSize: 10.sp)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 10.5.sp),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

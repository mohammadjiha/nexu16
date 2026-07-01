import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import 'commission_invoice_model.dart';
import 'invoice_pdf_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Super Admin view — reads global `commissionInvoices` collection,
/// filterable by gym, grouped by gymName.
// ─────────────────────────────────────────────────────────────────────────────
class SuperAdminInvoicesScreen extends StatefulWidget {
  const SuperAdminInvoicesScreen({super.key});

  @override
  State<SuperAdminInvoicesScreen> createState() =>
      _SuperAdminInvoicesScreenState();
}

class _SuperAdminInvoicesScreenState
    extends State<SuperAdminInvoicesScreen> {
  static const _bg   = Color(0xFF1C1C1E);
  static const _card = Color(0xFF2C2C2E);
  static const _cyan = Color(0xFF00E5FF);

  String _selectedGymId = 'all';
  String _search = '';
  String _filter = 'all'; // 'all' | 'stripe' | 'credit'

  Stream<List<CommissionInvoice>> _stream() {
    return FirebaseFirestore.instance
        .collection('commissionInvoices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CommissionInvoice.fromMap(d.id, d.data()))
            .toList());
  }

  List<CommissionInvoice> _applyFilters(List<CommissionInvoice> all) {
    var list = all;
    if (_selectedGymId != 'all') {
      list = list.where((i) => i.gymId == _selectedGymId).toList();
    }
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
          i.gymName.toLowerCase().contains(q) ||
          i.paidByName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  // Build gym dropdown options from all invoices
  Map<String, String> _gymMap(List<CommissionInvoice> all) {
    final map = <String, String>{};
    for (final inv in all) {
      if (inv.gymId.isNotEmpty) {
        map[inv.gymId] =
            inv.gymName.isNotEmpty ? inv.gymName : inv.gymId;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text('All Gym Invoices',
            style: TextStyle(
                fontSize: 15.sp, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFilterChips(),
        ),
      ),
      body: StreamBuilder<List<CommissionInvoice>>(
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
          final gymMap = _gymMap(all);
          final filtered = _applyFilters(all);

          return Column(
            children: [
              // Search bar + gym selector row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: _buildSearch()),
                    const SizedBox(width: 8),
                    _buildGymDropdown(gymMap),
                  ],
                ),
              ),

              // Summary banner
              _buildSummaryBanner(filtered),

              // Grouped list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No invoices found',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13.sp)))
                    : _selectedGymId == 'all'
                        ? _buildGroupedList(filtered)
                        : _buildFlatList(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _filterChip('All', 'all'),
          const SizedBox(width: 8),
          _filterChip('Stripe', 'stripe'),
          const SizedBox(width: 8),
          _filterChip('Credit', 'credit'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String val) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _cyan : _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: sel ? Colors.black : Colors.white70,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 11.sp,
            )),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search…',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      onChanged: (v) => setState(() => _search = v.toLowerCase()),
    );
  }

  Widget _buildGymDropdown(Map<String, String> gymMap) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Gyms')),
      ...gymMap.entries.map(
        (e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGymId,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: items,
          onChanged: (v) =>
              setState(() => _selectedGymId = v ?? 'all'),
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(List<CommissionInvoice> filtered) {
    final totalJod = filtered.fold<double>(
        0, (s, i) => s + i.commissionJod);
    final gymCount = filtered.map((i) => i.gymId).toSet().length;

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
          Text('${filtered.length} invoices · $gymCount gyms',
              style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
          Text('${totalJod.toStringAsFixed(3)} JOD',
              style: TextStyle(
                  color: _cyan,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Group by gymName
  Widget _buildGroupedList(List<CommissionInvoice> filtered) {
    // Build ordered groups
    final groups = <String, List<CommissionInvoice>>{};
    final gymNames = <String, String>{}; // gymId → gymName
    for (final inv in filtered) {
      groups.putIfAbsent(inv.gymId, () => []).add(inv);
      if (inv.gymName.isNotEmpty) gymNames[inv.gymId] = inv.gymName;
    }

    final gymIds = groups.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: gymIds.length,
      itemBuilder: (_, i) {
        final gId = gymIds[i];
        final gName = gymNames[gId] ?? gId;
        final gInvoices = groups[gId]!;
        final gTotal = gInvoices.fold<double>(
            0, (s, inv) => s + inv.commissionJod);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym header
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.sports_gymnastics,
                        color: _cyan, size: 16),
                    const SizedBox(width: 8),
                    Text(gName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold)),
                  ]),
                  Text('${gTotal.toStringAsFixed(3)} JOD',
                      style: TextStyle(
                          color: _cyan, fontSize: 12.sp)),
                ],
              ),
            ),
            ...gInvoices.map(_buildCard),
          ],
        );
      },
    );
  }

  Widget _buildFlatList(List<CommissionInvoice> filtered) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildCard(filtered[i]),
    );
  }

  Widget _buildCard(CommissionInvoice inv) {
    final byCredit = inv.paidByCredit;
    final dateStr =
        DateFormat('dd MMM yyyy  HH:mm').format(inv.createdAt);
    final statusColor = byCredit ? Colors.green : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                inv.operationLabel,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${inv.commissionJod.toStringAsFixed(3)} JOD',
                style: TextStyle(
                    color: _cyan,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (inv.playerName.isNotEmpty)
              Text(inv.playerName,
                  style: TextStyle(
                      color: Colors.white60, fontSize: 10.sp)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(inv.paidByName.isNotEmpty
                    ? inv.paidByName
                    : inv.paidByRole,
                    style: TextStyle(
                        color: Colors.white38, fontSize: 9.5.sp)),
                Text(dateStr,
                    style: TextStyle(
                        color: Colors.white38, fontSize: 9.sp)),
              ],
            ),
            const SizedBox(height: 2),
            Text(inv.invoiceNumber,
                style: TextStyle(
                    color: Colors.white24,
                    fontSize: 8.5.sp,
                    fontFamily: 'monospace')),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: _cyan, size: 20),
          tooltip: 'Print invoice',
          onPressed: () => printCommissionInvoice(inv),
        ),
      ),
    );
  }
}

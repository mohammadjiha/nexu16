import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'commission_service.dart';

// ─── Check if commission is enabled for a gym ────────────────────────────────
Future<bool> _isCommissionEnabled(String gymId) async {
  if (gymId.isEmpty) return true;
  try {
    final doc = await FirebaseFirestore.instance.collection('gyms').doc(gymId).get();
    if (!doc.exists) return true;
    final data = doc.data();
    // commissionEnabled defaults to true if field is absent
    return data?['commissionEnabled'] != false;
  } catch (_) {
    return true; // fail open — don't block operation on network error
  }
}

// ─── Single player commission dialog ─────────────────────────────────────────
Future<bool> showCommissionPaymentDialog({
  required BuildContext context,
  required double monthlyPrice,
  required int months,
  required String gymId,
  required String playerName,
  required String operationType,
}) async {
  // Skip payment entirely if gym is in free trial mode
  final enabled = await _isCommissionEnabled(gymId);
  if (!enabled) return true;
  final rate = getCommissionRate(months);
  final roundedMonthly = double.parse(monthlyPrice.toStringAsFixed(2));
  final total = roundedMonthly * months;
  final commission = double.parse((total * rate).toStringAsFixed(3));
  final ratePercent = (rate * 100).toStringAsFixed(0);

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.payment, color: Color(0xFF00E5FF)),
          SizedBox(width: 8),
          Text('تأكيد الدفع',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _infoRow('اشتراك اللاعب',
              '${roundedMonthly.toStringAsFixed(2)} د.أ × $months شهر'),
          _infoRow('إجمالي الاشتراك', '${total.toStringAsFixed(2)} د.أ'),
          const Divider(color: Colors.white24),
          _infoRow('عمولة المنصة ($ratePercent%)',
              '${commission.toStringAsFixed(3)} د.أ',
              highlight: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'أي رصيد متاح سيُخصم تلقائياً',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('ادفع الآن',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  if (!context.mounted) return false;

  return _processPayment(
    context: context,
    createFuture: () => CommissionService.createPayment(
      monthlyPrice: roundedMonthly,
      months: months,
      gymId: gymId,
      playerName: playerName,
      operationType: operationType,
    ),
    getClientSecret: (r) => (r as CommissionResult).clientSecret,
    getPaymentIntentId: (r) => (r as CommissionResult).paymentIntentId,
    getCreditUsed: (r) => (r as CommissionResult).creditUsed,
    isFullyByCredit: (r) => (r as CommissionResult).fullyPaidByCredit,
    getRate: (r) => (r as CommissionResult).rate,
    getCommissionJod: (r) => (r as CommissionResult).commissionJod,
    gymId: gymId,
    playerName: playerName,
    operationType: operationType,
    months: months,
    monthlyPrice: roundedMonthly,
  );
}

// ─── Bulk import commission dialog ────────────────────────────────────────────
Future<bool> showBulkCommissionPaymentDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> players,
  required String gymId,
}) async {
  // Skip payment entirely if gym is in free trial mode
  final enabled = await _isCommissionEnabled(gymId);
  if (!enabled) return true;

  // Pre-calculate total
  double totalCommission = 0;
  for (final p in players) {
    final monthly = (p['monthlyPrice'] as num?)?.toDouble() ?? 0;
    final months = (p['months'] as num?)?.toInt() ?? 1;
    final rate = getCommissionRate(months);
    totalCommission += monthly * months * rate;
  }
  totalCommission = double.parse(totalCommission.toStringAsFixed(3));

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.group_add, color: Color(0xFF00E5FF)),
          SizedBox(width: 8),
          Text('عمولة الاستيراد',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _infoRow('عدد اللاعبين', '${players.length} لاعب'),
          const Divider(color: Colors.white24),
          _infoRow('إجمالي العمولة',
              '${totalCommission.toStringAsFixed(3)} د.أ',
              highlight: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'أي رصيد متاح سيُخصم تلقائياً قبل الدفع',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('ادفع وأضف الكل',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  if (!context.mounted) return false;

  return _processPayment(
    context: context,
    createFuture: () => CommissionService.createBulkPayment(
      players: players,
      gymId: gymId,
    ),
    getClientSecret: (r) => (r as BulkCommissionResult).clientSecret,
    getPaymentIntentId: (r) => (r as BulkCommissionResult).paymentIntentId,
    getCreditUsed: (r) => (r as BulkCommissionResult).creditUsed,
    isFullyByCredit: (r) => (r as BulkCommissionResult).fullyPaidByCredit,
    getRate: (r) => 0,
    getCommissionJod: (r) => (r as BulkCommissionResult).totalCommissionJod,
    gymId: gymId,
    playerName: 'Bulk Import (${players.length} players)',
    operationType: 'bulk_import',
    months: 0,
    monthlyPrice: 0,
  );
}

// ─── Shared payment processing logic ─────────────────────────────────────────
Future<bool> _processPayment({
  required BuildContext context,
  required Future<dynamic> Function() createFuture,
  required String? Function(dynamic) getClientSecret,
  required String? Function(dynamic) getPaymentIntentId,
  required double Function(dynamic) getCreditUsed,
  required bool Function(dynamic) isFullyByCredit,
  required double Function(dynamic) getRate,
  required double Function(dynamic) getCommissionJod,
  // Invoice fields
  required String gymId,
  required String playerName,
  required String operationType,
  required int months,
  required double monthlyPrice,
}) async {
  OverlayEntry? loadingEntry;
  try {
    loadingEntry = _showLoading(context);
    final result = await createFuture();
    loadingEntry.remove();
    loadingEntry = null;

    final creditUsed = getCreditUsed(result);
    final rate = getRate(result);
    final commissionJod = getCommissionJod(result);

    // Fully covered by credit — save credit invoice, no Stripe needed
    if (isFullyByCredit(result)) {
      // Fire-and-forget invoice save (don't block user)
      CommissionService.saveCreditInvoice(
        creditUsed: creditUsed,
        gymId: gymId,
        playerName: playerName,
        operationType: operationType,
        months: months,
        monthlyPrice: monthlyPrice,
        rate: rate,
        commissionJod: commissionJod,
      ).catchError((_) {}); // Ignore errors — invoice is secondary

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم الدفع من رصيدك (${creditUsed.toStringAsFixed(3)} د.أ)'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
      return true;
    }

    final clientSecret = getClientSecret(result);
    final paymentIntentId = getPaymentIntentId(result);
    if (clientSecret == null || paymentIntentId == null) {
      throw Exception('لم يتم إنشاء طلب الدفع');
    }

    if (!context.mounted) return false;

    // Show Stripe Payment Sheet
    await CommissionService.showPaymentSheet(clientSecret: clientSecret);

    if (!context.mounted) return false;

    // Verify on server + save invoice
    loadingEntry = _showLoading(context);
    final verified = await CommissionService.verifyPayment(
      paymentIntentId: paymentIntentId,
      creditUsed: creditUsed,
      gymId: gymId,
      playerName: playerName,
      operationType: operationType,
      months: months,
      monthlyPrice: monthlyPrice,
      rate: rate,
      commissionJod: commissionJod,
    );
    loadingEntry.remove();
    loadingEntry = null;

    return verified;
  } on StripeException catch (e) {
    loadingEntry?.remove();
    if (context.mounted) {
      await _showError(context,
          e.error.localizedMessage ?? e.error.code.name);
    }
    return false;
  } catch (e) {
    loadingEntry?.remove();
    if (context.mounted) {
      await _showError(context, e.toString().replaceAll('Exception: ', ''));
    }
    return false;
  }
}

Future<void> _showError(BuildContext context, String message) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text('خطأ', style: TextStyle(color: Colors.red)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

OverlayEntry _showLoading(BuildContext context) {
  final entry = OverlayEntry(
    builder: (_) => Container(
      color: Colors.black54,
      child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}

Widget _infoRow(String label, String value, {bool highlight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF00E5FF) : Colors.white,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 16 : 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      ],
    ),
  );
}

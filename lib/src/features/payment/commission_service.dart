import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

double getCommissionRate(int months) {
  if (months >= 6) return 0.03;
  if (months >= 3) return 0.05;
  return 0.07;
}

class CommissionResult {
  final bool fullyPaidByCredit;
  final double creditUsed;
  final double commissionJod;
  final double subscriptionTotal;
  final double rate;
  final String? clientSecret;
  final String? paymentIntentId;
  final double remainingJod;

  CommissionResult({
    required this.fullyPaidByCredit,
    required this.creditUsed,
    required this.commissionJod,
    required this.subscriptionTotal,
    required this.rate,
    this.clientSecret,
    this.paymentIntentId,
    this.remainingJod = 0,
  });
}

class BulkCommissionResult {
  final bool fullyPaidByCredit;
  final double creditUsed;
  final double totalCommissionJod;
  final double remainingJod;
  final String? clientSecret;
  final String? paymentIntentId;

  BulkCommissionResult({
    required this.fullyPaidByCredit,
    required this.creditUsed,
    required this.totalCommissionJod,
    this.remainingJod = 0,
    this.clientSecret,
    this.paymentIntentId,
  });
}

class CommissionService {
  static final _functions = FirebaseFunctions.instance;

  static String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Single player payment ──────────────────────────────────────────────────
  static Future<CommissionResult> createPayment({
    required double monthlyPrice,
    required int months,
    required String gymId,
    required String playerName,
    required String operationType,
  }) async {
    final callable = _functions.httpsCallable('createCommissionPayment');
    final result = await callable.call({
      'monthlyPrice': monthlyPrice,
      'months': months,
      'gymId': gymId,
      'playerName': playerName,
      'operationType': operationType,
      'userUid': _currentUid,
    });

    final data = result.data as Map<String, dynamic>;
    return CommissionResult(
      fullyPaidByCredit: data['fullyPaidByCredit'] as bool? ?? false,
      creditUsed: (data['creditUsed'] as num?)?.toDouble() ?? 0,
      commissionJod: (data['commissionJod'] as num?)?.toDouble() ?? 0,
      subscriptionTotal: (data['subscriptionTotal'] as num?)?.toDouble() ?? 0,
      rate: (data['rate'] as num?)?.toDouble() ?? 0,
      clientSecret: data['clientSecret'] as String?,
      paymentIntentId: data['paymentIntentId'] as String?,
      remainingJod: (data['remainingJod'] as num?)?.toDouble() ?? 0,
    );
  }

  // ── Bulk import payment ────────────────────────────────────────────────────
  static Future<BulkCommissionResult> createBulkPayment({
    required List<Map<String, dynamic>> players,
    required String gymId,
  }) async {
    final callable = _functions.httpsCallable('createBulkCommissionPayment');
    final result = await callable.call({
      'players': players,
      'gymId': gymId,
      'userUid': _currentUid,
    });

    final data = result.data as Map<String, dynamic>;
    return BulkCommissionResult(
      fullyPaidByCredit: data['fullyPaidByCredit'] as bool? ?? false,
      creditUsed: (data['creditUsed'] as num?)?.toDouble() ?? 0,
      totalCommissionJod: (data['totalCommissionJod'] as num?)?.toDouble() ?? 0,
      remainingJod: (data['remainingJod'] as num?)?.toDouble() ?? 0,
      clientSecret: data['clientSecret'] as String?,
      paymentIntentId: data['paymentIntentId'] as String?,
    );
  }

  // ── Show Stripe Payment Sheet ──────────────────────────────────────────────
  static Future<void> showPaymentSheet({required String clientSecret}) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'NEXUS Sports',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  // ── Verify payment on server + save invoice ────────────────────────────────
  static Future<bool> verifyPayment({
    required String paymentIntentId,
    double creditUsed = 0,
    // Invoice fields (optional — Cloud Function auto-fetches user/gym info)
    String gymId = '',
    String playerName = '',
    String operationType = '',
    int months = 0,
    double monthlyPrice = 0,
    double rate = 0,
    double commissionJod = 0,
  }) async {
    final callable = _functions.httpsCallable('verifyCommissionPayment');
    final result = await callable.call({
      'paymentIntentId': paymentIntentId,
      'userUid': _currentUid,
      'creditUsed': creditUsed,
      'gymId': gymId,
      'playerName': playerName,
      'operationType': operationType,
      'months': months,
      'monthlyPrice': monthlyPrice,
      'rate': rate,
      'commissionJod': commissionJod,
    });
    final data = result.data as Map<String, dynamic>;
    return data['verified'] == true;
  }

  // ── Save credit-only invoice (no Stripe) ──────────────────────────────────
  static Future<void> saveCreditInvoice({
    double creditUsed = 0,
    String gymId = '',
    String playerName = '',
    String operationType = '',
    int months = 0,
    double monthlyPrice = 0,
    double rate = 0,
    double commissionJod = 0,
  }) async {
    final callable = _functions.httpsCallable('saveCreditInvoice');
    await callable.call({
      'userUid': _currentUid,
      'gymId': gymId,
      'playerName': playerName,
      'operationType': operationType,
      'months': months,
      'monthlyPrice': monthlyPrice,
      'rate': rate,
      'commissionJod': commissionJod,
      'creditUsed': creditUsed,
    });
  }

  // ── Add credit (after player delete) ──────────────────────────────────────
  static Future<void> addCredit({
    required double amount,
    required String reason,
  }) async {
    if (amount <= 0) return;
    final callable = _functions.httpsCallable('addCommissionCredit');
    await callable.call({
      'userUid': _currentUid,
      'creditAmount': amount,
      'reason': reason,
    });
  }

  // ── Calculate refund credit on delete ─────────────────────────────────────
  static double calcDeleteCredit({
    required double commissionPaid,
    required DateTime subscriptionStart,
    required DateTime subscriptionEnd,
    required DateTime deleteDate,
  }) {
    final totalDays = subscriptionEnd.difference(subscriptionStart).inDays;
    if (totalDays <= 0) return 0;
    final usedDays =
        deleteDate.difference(subscriptionStart).inDays.clamp(0, totalDays);
    final usedRatio = usedDays / totalDays;
    final earnedCommission = commissionPaid * usedRatio;
    final refund = commissionPaid - earnedCommission;
    return double.parse(refund.toStringAsFixed(3));
  }
}

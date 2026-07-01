import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionInvoice {
  final String id;
  final String invoiceNumber;
  final String paymentIntentId;
  final int stripeAmount;
  final String currency;
  final String paidByUid;
  final String paidByRole;
  final String paidByName;
  final String gymId;
  final String gymName;
  final String playerName;
  final String operationType;
  final int months;
  final double monthlyPrice;
  final double rate;
  final double commissionJod;
  final double creditUsed;
  final String status;
  final DateTime createdAt;

  CommissionInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.paymentIntentId,
    required this.stripeAmount,
    required this.currency,
    required this.paidByUid,
    required this.paidByRole,
    required this.paidByName,
    required this.gymId,
    required this.gymName,
    required this.playerName,
    required this.operationType,
    required this.months,
    required this.monthlyPrice,
    required this.rate,
    required this.commissionJod,
    required this.creditUsed,
    required this.status,
    required this.createdAt,
  });

  factory CommissionInvoice.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return CommissionInvoice(
      id: id,
      invoiceNumber: m['invoiceNumber'] as String? ?? '',
      paymentIntentId: m['paymentIntentId'] as String? ?? '',
      stripeAmount: (m['stripeAmount'] as num?)?.toInt() ?? 0,
      currency: m['currency'] as String? ?? 'usd',
      paidByUid: m['paidByUid'] as String? ?? '',
      paidByRole: m['paidByRole'] as String? ?? 'admin',
      paidByName: m['paidByName'] as String? ?? '',
      gymId: m['gymId'] as String? ?? '',
      gymName: m['gymName'] as String? ?? '',
      playerName: m['playerName'] as String? ?? '',
      operationType: m['operationType'] as String? ?? '',
      months: (m['months'] as num?)?.toInt() ?? 0,
      monthlyPrice: (m['monthlyPrice'] as num?)?.toDouble() ?? 0,
      rate: (m['rate'] as num?)?.toDouble() ?? 0,
      commissionJod: (m['commissionJod'] as num?)?.toDouble() ?? 0,
      creditUsed: (m['creditUsed'] as num?)?.toDouble() ?? 0,
      status: m['status'] as String? ?? 'paid',
      createdAt: parseDate(m['createdAt']),
    );
  }

  String get operationLabel {
    switch (operationType) {
      case 'add_player': return 'Add Player';
      case 'renew_subscription': return 'Renew Subscription';
      case 'edit_subscription': return 'Edit Subscription';
      case 'bulk_import': return 'Bulk Import';
      default: return operationType;
    }
  }

  bool get paidByCredit => status == 'paid_by_credit';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'shop_product_model.dart';

class ShopPaymentResult {
  final bool fullyPaidByCredit; // always false for shop (no credit system here)
  final String? clientSecret;
  final String? paymentIntentId;
  final double unitPrice;
  final double totalAmount;
  final int quantity;

  ShopPaymentResult({
    this.fullyPaidByCredit = false,
    this.clientSecret,
    this.paymentIntentId,
    required this.unitPrice,
    required this.totalAmount,
    required this.quantity,
  });
}

class ShopService {
  static final _db = FirebaseFirestore.instance;
  static final _functions = FirebaseFunctions.instance;
  static final _storage = FirebaseStorage.instance;

  static String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Product catalog (read) ────────────────────────────────────────────────
  static Stream<List<ShopProduct>> activeProductsStream() {
    return _db
        .collection('shopProducts')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ShopProduct.fromMap(d.id, d.data()))
            .toList());
  }

  /// All products, including inactive — for Super Admin management.
  static Stream<List<ShopProduct>> allProductsStream() {
    return _db.collection('shopProducts').snapshots().map((snap) => snap.docs
        .map((d) => ShopProduct.fromMap(d.id, d.data()))
        .toList());
  }

  // ── Product catalog (write) — Super Admin only, enforced by rules too ────
  static Future<void> createProduct(ShopProduct product) async {
    await _db.collection('shopProducts').add({
      ...product.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateProduct(String productId, ShopProduct product) async {
    await _db.collection('shopProducts').doc(productId).update(product.toMap());
  }

  static Future<void> deleteProduct(String productId) async {
    await _db.collection('shopProducts').doc(productId).delete();
  }

  static Future<void> setProductActive(String productId, bool isActive) async {
    await _db.collection('shopProducts').doc(productId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads a product image to Storage and returns its download URL.
  static Future<String?> uploadProductImage(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      final ref = _storage
          .ref()
          .child('shopProducts/${DateTime.now().microsecondsSinceEpoch}_$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = await ref.putData(fileBytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading shop product image: $e');
      return null;
    }
  }

  // ── Checkout (Stripe) ─────────────────────────────────────────────────────
  static Future<ShopPaymentResult> createPayment({
    required String productId,
    required int quantity,
    required String gymId,
  }) async {
    final callable = _functions.httpsCallable('createShopPayment');
    final result = await callable.call({
      'productId': productId,
      'quantity': quantity,
      'gymId': gymId,
    });
    final data = result.data as Map<String, dynamic>;
    return ShopPaymentResult(
      clientSecret: data['clientSecret'] as String?,
      paymentIntentId: data['paymentIntentId'] as String?,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? quantity,
    );
  }

  static Future<void> showPaymentSheet({required String clientSecret}) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'NEXUS Sports',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  static Future<String?> verifyPayment({required String paymentIntentId}) async {
    final callable = _functions.httpsCallable('verifyShopPayment');
    final result = await callable.call({'paymentIntentId': paymentIntentId});
    final data = result.data as Map<String, dynamic>;
    if (data['verified'] != true) return null;
    return data['orderId'] as String?;
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  /// The current player's own purchase history.
  static Stream<List<ShopOrder>> myOrdersStream() {
    if (_currentUid.isEmpty) return Stream.value(const []);
    return _db
        .collection('shopOrders')
        .where('uid', isEqualTo: _currentUid)
        .snapshots()
        .map((snap) {
      final orders =
          snap.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList();
      orders.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return orders;
    });
  }

  /// Orders awaiting pickup at a given gym — for coach/admin fulfillment.
  static Stream<List<ShopOrder>> pendingPickupsForGymStream(String gymId) {
    return _db
        .collection('shopOrders')
        .where('gymId', isEqualTo: gymId)
        .where('status', isEqualTo: 'pending_pickup')
        .snapshots()
        .map((snap) {
      final orders =
          snap.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList();
      orders.sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      return orders;
    });
  }

  static Future<void> markPickedUp(String orderId) async {
    final callable = _functions.httpsCallable('markShopOrderPickedUp');
    await callable.call({'orderId': orderId});
  }
}

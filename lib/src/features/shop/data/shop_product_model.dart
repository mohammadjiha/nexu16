import 'package:cloud_firestore/cloud_firestore.dart';

/// A single Nexus Shop product. Central catalog — not gym-scoped — managed
/// exclusively by Super Admin, purchased by players from any gym, picked up
/// in person at their own gym.
class ShopProduct {
  final String id;
  final String name;
  final String description;
  final double price; // JOD, before discount
  final double discountPercent; // 0-100
  final List<String> images;
  final String category;
  final int stock;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountPercent = 0,
    this.images = const [],
    this.category = '',
    this.stock = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasDiscount => discountPercent > 0;

  double get effectivePrice =>
      double.parse((price * (1 - discountPercent / 100)).toStringAsFixed(3));

  bool get isSoldOut => stock <= 0;

  String get primaryImage => images.isNotEmpty ? images.first : '';

  factory ShopProduct.fromMap(String id, Map<String, dynamic> map) {
    return ShopProduct(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
      images: (map['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      category: map['category'] as String? ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'description': description.trim(),
        'price': price,
        'discountPercent': discountPercent,
        'images': images,
        'category': category.trim(),
        'stock': stock,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

/// A player's purchase of a shop product — paid via Stripe, collected in
/// person at their gym.
class ShopOrder {
  final String id;
  final String uid;
  final String buyerName;
  final String gymId;
  final String productId;
  final String productName;
  final String productImage;
  final double unitPrice;
  final int quantity;
  final double totalAmount;
  final String status; // pending_pickup | picked_up
  final bool stockIssue;
  final DateTime? createdAt;
  final DateTime? pickedUpAt;
  final String? pickedUpByName;

  const ShopOrder({
    required this.id,
    required this.uid,
    required this.buyerName,
    required this.gymId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.unitPrice,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    this.stockIssue = false,
    this.createdAt,
    this.pickedUpAt,
    this.pickedUpByName,
  });

  bool get isPickedUp => status == 'picked_up';

  factory ShopOrder.fromMap(String id, Map<String, dynamic> map) {
    return ShopOrder(
      id: id,
      uid: map['uid'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '',
      gymId: map['gymId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productImage: map['productImage'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending_pickup',
      stockIssue: map['stockIssue'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']),
      pickedUpAt: _parseDate(map['pickedUpAt']),
      pickedUpByName: map['pickedUpByName'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

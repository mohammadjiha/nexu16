import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../data/shop_product_model.dart';
import '../../data/shop_service.dart';

class MyShopOrdersScreen extends StatelessWidget {
  const MyShopOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 1.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16.sp, color: const Color(0xFF1C1C1E)),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'طلباتي',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ShopOrder>>(
                stream: ShopService.myOrdersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF9500)),
                    );
                  }
                  final orders = snapshot.data ?? const [];
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 42.sp, color: const Color(0xFFC7C7CC)),
                          SizedBox(height: 2.h),
                          Text(
                            'لا يوجد طلبات بعد',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 4.h),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => SizedBox(height: 2.5.w),
                    itemBuilder: (context, i) => _OrderCard(order: orders[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ShopOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isPicked = order.isPickedUp;
    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.5.w),
            child: Container(
              width: 15.w,
              height: 15.w,
              color: const Color(0xFFF5F5F7),
              child: order.productImage.isNotEmpty
                  ? Image.network(order.productImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag_rounded,
                          color: const Color(0xFFC7C7CC)))
                  : Icon(Icons.shopping_bag_rounded,
                      color: const Color(0xFFC7C7CC)),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${order.quantity} × ${order.unitPrice.toStringAsFixed(2)} د.أ  —  ${order.totalAmount.toStringAsFixed(2)} د.أ',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
            decoration: BoxDecoration(
              color: isPicked
                  ? const Color(0xFF34C759).withValues(alpha: 0.12)
                  : const Color(0xFFFF9500).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2.5.w),
            ),
            child: Text(
              isPicked ? 'تم الاستلام' : 'جاهز للاستلام',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: isPicked ? const Color(0xFF34C759) : const Color(0xFFFF9500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../shop/data/shop_product_model.dart';
import '../../../shop/data/shop_service.dart';

/// Gym staff (coach/admin/owner) view of orders awaiting pickup at this gym.
/// Reused as-is from both the admin "More" menu and coach screens — the
/// underlying markShopOrderPickedUp Cloud Function scopes access to the
/// caller's own gym (or Super Admin) regardless of which entry point is used.
class ShopPickupsScreen extends StatefulWidget {
  final String gymId;
  const ShopPickupsScreen({super.key, required this.gymId});

  @override
  State<ShopPickupsScreen> createState() => _ShopPickupsScreenState();
}

class _ShopPickupsScreenState extends State<ShopPickupsScreen> {
  final Set<String> _confirming = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: Text(
          'استلام طلبات المتجر',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<ShopOrder>>(
        stream: ShopService.pendingPickupsForGymStream(widget.gymId),
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
                  const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 40),
                  SizedBox(height: 1.5.h),
                  Text('لا توجد طلبات بانتظار الاستلام',
                      style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 6.h),
            itemCount: orders.length,
            separatorBuilder: (_, __) => SizedBox(height: 2.5.w),
            itemBuilder: (context, i) {
              final order = orders[i];
              final isConfirming = _confirming.contains(order.id);
              return Container(
                padding: EdgeInsets.all(3.5.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151C),
                  borderRadius: BorderRadius.circular(4.w),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2.5.w),
                      child: Container(
                        width: 14.w,
                        height: 14.w,
                        color: Colors.white.withValues(alpha: 0.05),
                        child: order.productImage.isNotEmpty
                            ? Image.network(order.productImage, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.shopping_bag_rounded, color: Colors.white24))
                            : const Icon(Icons.shopping_bag_rounded, color: Colors.white24),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.productName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 0.4.h),
                          Text('${order.buyerName}  ·  ${order.quantity}× ${order.unitPrice.toStringAsFixed(2)} د.أ',
                              style: TextStyle(fontSize: 10.5.sp, color: Colors.white38)),
                          if (order.stockIssue)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('⚠ تعارض في المخزون وقت الدفع — راجع الكمية يدوياً',
                                  style: TextStyle(fontSize: 9.5.sp, color: const Color(0xFFFF9500))),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 4.5.h,
                      child: ElevatedButton(
                        onPressed: isConfirming ? null : () => _confirm(order.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.5.w)),
                        ),
                        child: isConfirming
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('تم الاستلام',
                                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirm(String orderId) async {
    setState(() => _confirming.add(orderId));
    try {
      await ShopService.markPickedUp(orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming.remove(orderId));
    }
  }
}

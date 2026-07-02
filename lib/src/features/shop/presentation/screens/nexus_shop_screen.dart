import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/shop_product_model.dart';
import '../../data/shop_service.dart';
import 'my_shop_orders_screen.dart';

class NexusShopScreen extends ConsumerWidget {
  const NexusShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Nexus Shop',
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
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MyShopOrdersScreen())),
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
                      child: Icon(Icons.receipt_long_rounded,
                          size: 17.sp, color: const Color(0xFF1C1C1E)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ShopProduct>>(
                stream: ShopService.activeProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF9500)),
                    );
                  }
                  final products = snapshot.data ?? const [];
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded,
                                size: 42.sp, color: const Color(0xFFC7C7CC)),
                            SizedBox(height: 2.h),
                            Text(
                              'لا توجد منتجات متاحة حالياً',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 4.h),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 3.5.w,
                      mainAxisSpacing: 3.5.w,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) =>
                        _ProductCard(product: products[i]),
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

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProductDetailSheet(product: product),
      ),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF5F5F7),
                    child: product.primaryImage.isNotEmpty
                        ? Image.network(product.primaryImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.image_not_supported_rounded,
                                color: const Color(0xFFC7C7CC), size: 26.sp))
                        : Icon(Icons.shopping_bag_rounded,
                            color: const Color(0xFFC7C7CC), size: 30.sp),
                  ),
                  if (product.hasDiscount)
                    PositionedDirectional(
                      top: 2.w,
                      start: 2.w,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 2.2.w, vertical: 0.6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                        child: Text(
                          '-${product.discountPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (product.isSoldOut)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Text(
                        'نفدت الكمية',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.6.h),
                  Row(
                    children: [
                      Text(
                        '${product.effectivePrice.toStringAsFixed(2)} د.أ',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        SizedBox(width: 1.5.w),
                        Text(
                          product.price.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: const Color(0xFFC7C7CC),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends ConsumerStatefulWidget {
  final ShopProduct product;
  const _ProductDetailSheet({required this.product});

  @override
  ConsumerState<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  int _quantity = 1;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final maxQty = p.stock.clamp(0, 99);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.w),
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: Container(
                    color: const Color(0xFFF5F5F7),
                    child: p.primaryImage.isNotEmpty
                        ? Image.network(p.primaryImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.image_not_supported_rounded,
                                color: const Color(0xFFC7C7CC), size: 32.sp))
                        : Icon(Icons.shopping_bag_rounded,
                            color: const Color(0xFFC7C7CC), size: 36.sp),
                  ),
                ),
              ),
              SizedBox(height: 2.5.h),
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1.h),
              Row(
                children: [
                  Text(
                    '${p.effectivePrice.toStringAsFixed(2)} د.أ',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF9500),
                    ),
                  ),
                  if (p.hasDiscount) ...[
                    SizedBox(width: 2.w),
                    Text(
                      p.price.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFFC7C7CC),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(1.5.w),
                      ),
                      child: Text(
                        'وفر ${p.discountPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 2.5.h),
              if (p.description.trim().isNotEmpty) ...[
                Text(
                  'الوصف',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  p.description,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    color: const Color(0xFF3C3C43),
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 2.5.h),
              ],
              if (p.isSoldOut)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Text(
                    'نفدت الكمية من هذا المنتج',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الكمية',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                      child: Row(
                        children: [
                          _qtyBtn(Icons.remove_rounded,
                              onTap: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null),
                          SizedBox(
                            width: 8.w,
                            child: Text(
                              '$_quantity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                          _qtyBtn(Icons.add_rounded,
                              onTap: _quantity < maxQty
                                  ? () => setState(() => _quantity++)
                                  : null),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.5.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 15.sp, color: const Color(0xFF8E8E93)),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'الاستلام من صالة النادي — الدفع الآن، والاستلام لاحقاً',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.5.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _processing ? null : _buyNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.5.w)),
                    ),
                    child: _processing
                        ? SizedBox(
                            width: 16.sp,
                            height: 16.sp,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'اشترِ الآن — ${(p.effectivePrice * _quantity).toStringAsFixed(2)} د.أ',
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(2.2.w),
        child: Icon(icon,
            size: 15.sp,
            color: onTap == null
                ? const Color(0xFFC7C7CC)
                : const Color(0xFF1C1C1E)),
      ),
    );
  }

  Future<void> _buyNow() async {
    final gymId = ref.read(currentGymIdProvider);
    if (gymId == null || gymId.isEmpty) {
      _showError('لا يمكن إتمام الشراء — الحساب غير مرتبط بنادٍ.');
      return;
    }

    setState(() => _processing = true);
    try {
      final result = await ShopService.createPayment(
        productId: widget.product.id,
        quantity: _quantity,
        gymId: gymId,
      );

      if (result.clientSecret == null || result.paymentIntentId == null) {
        throw Exception('تعذر إنشاء طلب الدفع');
      }

      if (!mounted) return;
      await ShopService.showPaymentSheet(clientSecret: result.clientSecret!);

      if (!mounted) return;
      final orderId =
          await ShopService.verifyPayment(paymentIntentId: result.paymentIntentId!);

      if (!mounted) return;
      if (orderId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم الدفع بنجاح! استلم طلبك من صالة النادي.'),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
          ),
        );
      } else {
        throw Exception('تعذر تأكيد الدفع');
      }
    } on StripeException catch (e) {
      _showError(e.error.localizedMessage ?? 'فشلت عملية الدفع');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
      ),
    );
  }
}

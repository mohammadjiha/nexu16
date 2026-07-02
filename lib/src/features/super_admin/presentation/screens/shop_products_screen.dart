import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../../shop/data/shop_product_model.dart';
import '../../../shop/data/shop_service.dart';

class ShopProductsScreen extends StatelessWidget {
  const ShopProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: Text(
          'منتجات متجر Nexus',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF9500),
        onPressed: () => _showProductEditor(context),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: Text(
          'منتج جديد',
          style: TextStyle(
            color: Colors.black,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<ShopProduct>>(
        stream: ShopService.allProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9500)),
            );
          }
          final products = snapshot.data ?? const [];
          if (products.isEmpty) {
            return Center(
              child: Text(
                'لا توجد منتجات — اضغط "منتج جديد" للبدء',
                style: TextStyle(color: Colors.white38, fontSize: 11.sp),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(height: 2.5.w),
            itemBuilder: (context, i) =>
                _ProductRow(product: products[i]),
          );
        },
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ShopProduct product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProductEditor(context, existing: product),
      child: Container(
        padding: EdgeInsets.all(3.w),
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
                width: 15.w,
                height: 15.w,
                color: Colors.white.withValues(alpha: 0.05),
                child: product.primaryImage.isNotEmpty
                    ? Image.network(product.primaryImage, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_rounded, color: Colors.white24))
                    : const Icon(Icons.shopping_bag_rounded, color: Colors.white24),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Text(
                        '${product.effectivePrice.toStringAsFixed(2)} د.أ',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF9500),
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        SizedBox(width: 1.5.w),
                        Text(
                          '(-${product.discountPercent.toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 10.sp, color: Colors.white38),
                        ),
                      ],
                      SizedBox(width: 2.w),
                      Text(
                        '·  مخزون: ${product.stock}',
                        style: TextStyle(fontSize: 10.sp, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: product.isActive,
              activeColor: const Color(0xFF34C759),
              onChanged: (v) => ShopService.setProductActive(product.id, v),
            ),
            GestureDetector(
              onTap: () => _confirmDelete(context, product),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF3B30), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ShopProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المنتج؟', style: TextStyle(color: Colors.white)),
        content: Text('سيتم حذف "${product.name}" نهائياً.',
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              ShopService.deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }
}

void _showProductEditor(BuildContext context, {ShopProduct? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductEditorSheet(existing: existing),
  );
}

class _ProductEditorSheet extends StatefulWidget {
  final ShopProduct? existing;
  const _ProductEditorSheet({this.existing});

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _categoryCtrl;
  late List<String> _images;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e != null ? e.price.toStringAsFixed(2) : '');
    _discountCtrl =
        TextEditingController(text: e != null && e.discountPercent > 0 ? e.discountPercent.toStringAsFixed(0) : '');
    _stockCtrl = TextEditingController(text: e != null ? e.stock.toString() : '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _images = List.of(e?.images ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF15151C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w,
              MediaQuery.of(context).viewInsets.bottom + 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 10.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                widget.existing == null ? 'منتج جديد' : 'تعديل المنتج',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.5.h),
              _imagesPicker(),
              SizedBox(height: 2.5.h),
              _field('اسم المنتج', _nameCtrl),
              SizedBox(height: 1.5.h),
              _field('الوصف', _descCtrl, maxLines: 4),
              SizedBox(height: 1.5.h),
              _field('الفئة (اختياري — مثلاً: بروتين، مكملات)', _categoryCtrl),
              SizedBox(height: 1.5.h),
              Row(
                children: [
                  Expanded(
                      child: _field('السعر (د.أ)', _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  SizedBox(width: 3.w),
                  Expanded(
                      child: _field('الخصم % (اختياري)', _discountCtrl,
                          keyboardType: TextInputType.number)),
                ],
              ),
              SizedBox(height: 1.5.h),
              _field('الكمية المتوفرة (المخزون)', _stockCtrl,
                  keyboardType: TextInputType.number),
              if (_error != null) ...[
                SizedBox(height: 1.5.h),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
              ],
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text('حفظ',
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagesPicker() {
    return SizedBox(
      height: 22.w,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._images.map((url) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3.w),
                      child: Image.network(url,
                          width: 22.w, height: 22.w, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 22.w, height: 22.w, color: Colors.white10,
                              child: const Icon(Icons.broken_image, color: Colors.white24))),
                    ),
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.remove(url)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black87, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          GestureDetector(
            onTap: _uploadingImage ? null : _pickImage,
            child: Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(color: Colors.white24, style: BorderStyle.solid),
              ),
              child: _uploadingImage
                  ? const Center(
                      child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Color(0xFFFF9500), strokeWidth: 2)))
                  : const Icon(Icons.add_photo_alternate_rounded, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    // 1200px max width @ 82% JPEG quality — sharp on retina product cards
    // without bloating upload time or Storage costs; matches the same
    // resolution/quality tradeoff already used for profile photos.
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null) return;

    setState(() => _uploadingImage = true);
    final bytes = await image.readAsBytes();
    final url = await ShopService.uploadProductImage(bytes, image.name);
    setState(() => _uploadingImage = false);

    if (url == null) {
      setState(() => _error = 'فشل رفع الصورة، حاول مرة أخرى');
      return;
    }
    setState(() {
      _images.add(url);
      _error = null;
    });
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: Colors.white54)),
        SizedBox(height: 0.7.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.5.h),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.w), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'اسم المنتج مطلوب');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'السعر غير صحيح');
      return;
    }
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
    });

    final product = ShopProduct(
      id: widget.existing?.id ?? '',
      name: name,
      description: _descCtrl.text.trim(),
      price: price,
      discountPercent: discount.clamp(0, 100),
      images: _images,
      category: _categoryCtrl.text.trim(),
      stock: stock < 0 ? 0 : stock,
      isActive: widget.existing?.isActive ?? true,
    );

    try {
      if (widget.existing == null) {
        await ShopService.createProduct(product);
      } else {
        await ShopService.updateProduct(widget.existing!.id, product);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'فشل الحفظ: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }
}

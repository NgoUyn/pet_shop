import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../admin/pages/admin_product_form_page.dart';
import '../../reviews/services/review_repository.dart';
import '../services/product_repository.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    this.showAdminActions = false,
  });

  final ProductItem product;
  final bool showAdminActions;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late ProductItem _currentProduct;
  String? _categoryName;
  List<ReviewItem> _reviews = [];
  List<ProductItem> _relatedProducts = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _loadCategoryName();
    _loadReviews();
    _loadRelatedProducts();
  }

  Future<void> _loadCategoryName() async {
    final name = await ProductRepository.instance.getCategoryName(widget.product.categoryId);
    if (mounted) {
      setState(() {
        _categoryName = name;
      });
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ReviewRepository.instance.getByProductId(_currentProduct.productId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Future<void> _loadRelatedProducts() async {
    try {
      final allProducts = await ProductRepository.instance.listActiveProducts(limit: 20);
      final related = allProducts
          .where((p) =>
              p.productId != _currentProduct.productId &&
              p.categoryId == _currentProduct.categoryId)
          .take(6)
          .toList();
      if (mounted) {
        setState(() {
          _relatedProducts = related;
        });
      }
    } catch (_) {}
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '$bufferđ';
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  Widget _buildHeroImage(ProductItem product) {
    final imageUrl = (product.imageUrl ?? '').trim();

    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 96,
                color: Color(0xFF3E7C63),
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 96,
                  color: Color(0xFF3E7C63),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Times New Roman',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Times New Roman',
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {Color background = const Color(0xFFF2F8F4), Color foreground = const Color(0xFF3E7C63)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Times New Roman',
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Times New Roman',
          ),
        ),
      ),
    );
  }

  Future<void> _editProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProductFormPage(product: _currentProduct)),
    );

    if (changed != true || !mounted) {
      return;
    }

    final refreshed = await ProductRepository.instance.getProductById(_currentProduct.productId);
    if (!mounted || refreshed == null) {
      return;
    }

    setState(() {
      _currentProduct = refreshed;
    });
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phụ kiện'),
        content: const Text('Bạn có chắc chắn muốn xóa phụ kiện này không? Sản phẩm sẽ bị ẩn khỏi cửa hàng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ProductRepository.instance.deleteProduct(_currentProduct.productId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    final description = (product.description ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết phụ kiện'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Image ──────────────────────────────────────────────
            _buildHeroImage(product),
            const SizedBox(height: 18),

            // ── Info Card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 720;

                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.productName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Times New Roman',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Admin actions (only visible to admin)
                      if (widget.showAdminActions)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildActionButton(
                              label: 'Chỉnh sửa',
                              icon: Icons.edit_outlined,
                              background: const Color(0xFFEAF3FF),
                              foreground: const Color(0xFF2F80ED),
                              onPressed: _editProduct,
                            ),
                            _buildActionButton(
                              label: 'Xóa',
                              icon: Icons.delete_outline,
                              background: const Color(0xFFFDECEC),
                              foreground: const Color(0xFFB42318),
                              onPressed: _deleteProduct,
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      _buildInfoRow('Mã phụ kiện', product.productId.toString()),
                      _buildInfoRow('Danh mục', _categoryName ?? 'Đang tải...'),
                      _buildInfoRow('Tồn kho', '${product.stockQuantity} sản phẩm'),
                      _buildInfoRow('Trạng thái', product.isActive ? 'Đang bán' : 'Ngừng bán'),
                      _buildInfoRow('Ngày tạo', _formatDateTime(product.createdAt.toLocal())),
                      if (description.isNotEmpty) ...[
                        const Text(
                          'Mô tả',
                          style: TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 15,
                            height: 1.45,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                      ],
                    ],
                  );

                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      _buildBadge(
                        product.stockQuantity > 0 ? 'Còn hàng' : 'Hết hàng',
                        background: product.stockQuantity > 0 ? const Color(0xFFD8EEE4) : const Color(0xFFFDECEC),
                        foreground: product.stockQuantity > 0 ? const Color(0xFF3E7C63) : const Color(0xFFB42318),
                      ),
                      const SizedBox(height: 10),
                      _buildBadge(
                        product.isActive ? 'Đang bán' : 'Ngừng bán',
                        background: product.isActive ? const Color(0xFFEAF3FF) : const Color(0xFFF3F4F6),
                        foreground: product.isActive ? const Color(0xFF2F80ED) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 10),
                      if (product.stockQuantity <= 5 && product.stockQuantity > 0)
                        _buildBadge(
                          'Sắp hết hàng',
                          background: const Color(0xFFFFF3E0),
                          foreground: Colors.orange,
                        ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7EAF0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sell_outlined, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 10),
                            const Text(
                              'Giá',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Times New Roman',
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatPrice(product.price),
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Times New Roman',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 20),
                        rightColumn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(child: rightColumn),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Đánh giá sản phẩm ──────────────────────────────────────
            _buildReviewsSection(),

            const SizedBox(height: 24),

            // ── Sản phẩm liên quan ─────────────────────────────────────
            _buildRelatedProductsSection(),
          ],
        ),
      ),
    );
  }

  // ── Reviews Section ──────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 24),
            const SizedBox(width: 6),
            Text(
              'Đánh giá (${_reviews.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Times New Roman',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Chưa có đánh giá nào cho sản phẩm này',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                  fontFamily: 'Times New Roman',
                ),
              ),
            ),
          )
        else
          ..._reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _buildReviewCard(ReviewItem review) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer name + date
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEAF3FF),
                child: Text(
                  (review.customerName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F80ED),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName ?? 'Khách hàng',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                    Text(
                      _formatDateTime(review.createdAt.toLocal()),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFFFB300),
                  );
                }),
              ),
            ],
          ),

          // Content
          if ((review.content ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.4,
                fontFamily: 'Times New Roman',
              ),
            ),
          ],

          // Images
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: review.imageUrls[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Related Products Section ─────────────────────────────────────────

  Widget _buildRelatedProductsSection() {
    if (_relatedProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sản phẩm liên quan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Times New Roman',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final related = _relatedProducts[index];
              return SizedBox(
                width: 150,
                child: _buildRelatedProductCard(related),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedProductCard(ProductItem product) {
    final imageUrl = (product.imageUrl ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              product: product,
              showAdminActions: widget.showAdminActions,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF9AA5B1)),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF9AA5B1)),
                        ),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                      fontFamily: 'Times New Roman',
                    ),
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

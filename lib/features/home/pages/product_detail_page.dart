import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../../reviews/services/review_repository.dart';
import '../services/product_repository.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product, this.showAdminActions = false});

  final ProductItem product;
  final bool showAdminActions;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isFavorited = false;
  List<ReviewItem>? _reviews;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ReviewRepository.instance
          .getByProductId(widget.product.productId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {}
  }

  Future<void> _loadFavoriteState() async {
    final isFavorited = await FavoriteRepository.instance
        .isProductFavorited(widget.product.productId);
    if (!mounted) return;
    setState(() {
      _isFavorited = isFavorited;
    });
  }

  Future<void> _ensureLoggedIn() async {
    if (AuthSession.instance.currentUserId.value != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _toggleFavorite() async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance
          .toggleProductFavorite(widget.product.productId);
      if (!mounted) return;
      setState(() {
        _isFavorited = !_isFavorited;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _addToCart() async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance
          .addProductToCart(productId: widget.product.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da them vao gio hang')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
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

  Widget _buildImage(String? url) {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.textLight, size: 54),
      );
    }

    return Image.network(
      normalized,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.background,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 54),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Yeu thich',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.red : AppColors.textDark,
            ),
          ),
          IconButton(
            tooltip: 'Them vao gio hang',
            onPressed: _addToCart,
            icon: const Icon(Icons.add_shopping_cart_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildImage(widget.product.imageUrl),
            ),
            const SizedBox(height: 14),
            Text(
              widget.product.productName,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatPrice(widget.product.price),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: FutureBuilder<String?>(
                future: ProductRepository.instance
                    .getCategoryName(widget.product.categoryId),
                builder: (context, snapshot) {
                  final categoryName = snapshot.data;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Mã sản phẩm', widget.product.productId.toString()),
                      _infoRow('Danh mục', categoryName?.isNotEmpty == true ? categoryName! : widget.product.categoryId.toString()),
                      _infoRow('Tồn kho', widget.product.stockQuantity.toString()),
                      _infoRow('Trạng thái', widget.product.isActive ? 'Đang bán' : 'Ngừng bán'),
                      _infoRow('Ngày tạo', widget.product.createdAt.toLocal().toString()),
                      const SizedBox(height: 8),
                      const Text(
                        'Mô tả',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.product.description ?? '').trim().isEmpty ? '-' : widget.product.description!.trim(),
                        style: const TextStyle(color: AppColors.textDark),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Reviews section
            const SizedBox(height: 20),
            if (_reviews != null && _reviews!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.star, size: 20, color: Color(0xFFFFB300)),
                  const SizedBox(width: 6),
                  Text(
                    'Đánh giá (${_reviews!.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_reviews!.fold(0, (sum, r) => sum + r.rating) / _reviews!.length).toStringAsFixed(1)} sao',
                    style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...(_reviews!.take(3).map((review) => _buildReviewCard(review))),
              if (_reviews!.length > 3) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllReviewsPage(
                            productName: widget.product.productName,
                            reviews: _reviews!,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Xem tất cả ${_reviews!.length} đánh giá',
                      style: const TextStyle(fontSize: 14, color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Chưa có đánh giá nào',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewItem review) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                review.customerName ?? 'Khách hàng',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Text(
                _formatReviewDate(review.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < review.rating ? Icons.star : Icons.star_border,
                size: 16,
                color: i < review.rating
                    ? const Color(0xFFFFB300)
                    : Colors.grey.shade300,
              );
            }),
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.content!,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ],
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      review.imageUrls[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }
}

class AllReviewsPage extends StatelessWidget {
  final String productName;
  final List<ReviewItem> reviews;

  const AllReviewsPage({
    super.key,
    required this.productName,
    required this.reviews,
  });

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Đánh giá: $productName'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final review = reviews[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      review.customerName ?? 'Khách hàng',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(review.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: i < review.rating
                          ? const Color(0xFFFFB300)
                          : Colors.grey.shade300,
                    );
                  }),
                ),
                if (review.content != null && review.content!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.content!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                  ),
                ],
                if (review.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: review.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            review.imageUrls[idx],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image, size: 30, color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

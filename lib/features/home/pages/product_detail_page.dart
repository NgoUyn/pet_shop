import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../services/product_repository.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final ProductItem product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
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
          ],
        ),
      ),
    );
  }
}

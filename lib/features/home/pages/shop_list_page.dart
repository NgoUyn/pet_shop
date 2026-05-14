import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import 'product_detail_page.dart';
import '../services/product_repository.dart';

class ShopListPage extends StatefulWidget {
  const ShopListPage({super.key});

  @override
  State<ShopListPage> createState() => _ShopListPageState();
}

class _ShopListPageState extends State<ShopListPage> {
  late Future<List<ProductItem>> _future;
  Set<int> _favoriteProductIds = {};
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = ProductRepository.instance.listActiveProducts();
    ProductRepository.instance.changeToken.addListener(_handleProductsChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    ProductRepository.instance.changeToken.removeListener(_handleProductsChanged);
    super.dispose();
  }

  void _handleProductsChanged() {
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ProductRepository.instance.listActiveProducts();
    });
    _loadFavorites();
  }

  void _startSearch() => setState(() => _isSearching = true);
  void _stopSearch() {
    _searchController.clear();
    setState(() { _isSearching = false; _query = ''; });
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoriteRepository.instance.listFavoriteProducts();
    if (!mounted) return;
    setState(() {
      _favoriteProductIds = favorites.map((item) => item.productId).toSet();
    });
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
        child: const Icon(Icons.image_outlined, color: AppColors.textLight, size: 44),
      );
    }

    return Image.network(
      normalized,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.background,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 44),
        );
      },
    );
  }

  Future<void> _addToCart(ProductItem item) async {
    final userId = AuthSession.instance.currentUserId.value;
      if (userId == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) return;
      if (AuthSession.instance.currentUserId.value == null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thêm vào giỏ hàng'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

      try {
      await CartRepository.instance.addProductToCart(productId: item.productId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã thêm vào giỏ hàng'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _toggleFavorite(ProductItem item) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted || AuthSession.instance.currentUserId.value == null) return;
    }

    try {
      await FavoriteRepository.instance.toggleProductFavorite(item.productId);
      setState(() {
        if (_favoriteProductIds.contains(item.productId)) {
          _favoriteProductIds.remove(item.productId);
        } else {
          _favoriteProductIds.add(item.productId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Widget _buildProductCard(ProductItem item) {
    final isFavorited = _favoriteProductIds.contains(item.productId);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(item.imageUrl),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Column(
                      children: [
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _toggleFavorite(item),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFavorited ? Icons.favorite : Icons.favorite_border,
                                color: isFavorited ? Colors.red : AppColors.textDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _addToCart(item),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.add_shopping_cart_outlined,
                                color: AppColors.textDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatPrice(item.price),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                style: const TextStyle(fontSize: 16, color: AppColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'Tìm sản phẩm...',
                  hintStyle: TextStyle(color: AppColors.textLight),
                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text('Cửa hàng vật phẩm'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_isSearching)
            IconButton(tooltip: 'Đóng', onPressed: _stopSearch, icon: const Icon(Icons.close))
          else ...[
            IconButton(tooltip: 'Tìm kiếm', onPressed: _startSearch, icon: const Icon(Icons.search)),
            IconButton(tooltip: 'Tải lại', onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ],
      ),
      body: FutureBuilder<List<ProductItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Không thể tải danh sách vật phẩm',
                style: const TextStyle(color: AppColors.textDark),
              ),
            );
          }

          final items = snapshot.data ?? [];
          final filtered = _query.isEmpty ? items : items.where((p) => p.productName.toLowerCase().contains(_query)).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _query.isEmpty ? 'Chưa có vật phẩm nào' : 'Không tìm thấy "$_query"',
                style: const TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(product: item),
                    ),
                  );
                },
                child: _buildProductCard(item),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/product_provider.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../widgets/product_card.dart';
import '../../product_detail/pages/product_detail_page.dart';
import '../services/product_repository.dart';

class ShopListPage extends StatefulWidget {
  const ShopListPage({super.key});

  @override
  State<ShopListPage> createState() => _ShopListPageState();
}

class _ShopListPageState extends State<ShopListPage> {
  Set<int> _favoriteProductIds = {};
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    ProductProvider.instance.addListener(_onProductsChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    ProductProvider.instance.removeListener(_onProductsChanged);
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _reload() {
    ProductProvider.instance.reload();
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

  @override
  Widget build(BuildContext context) {
    final provider = ProductProvider.instance;
    final items = provider.products;
    final isLoading = provider.isLoading;
    final error = provider.error;

    final filtered = _query.isEmpty
        ? items
        : items.where((p) => p.productName.toLowerCase().contains(_query)).toList();

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
      body: _buildBody(filtered, isLoading, error),
    );
  }

  Widget _buildBody(List<ProductItem> filtered, bool isLoading, String? error) {
    if (isLoading && filtered.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && filtered.isEmpty) {
      return Center(
        child: Text(
          error,
          style: const TextStyle(color: AppColors.textDark),
        ),
      );
    }

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
        final isFavorited = _favoriteProductIds.contains(item.productId);
        return ProductCard(
          item: item,
          isFavorited: isFavorited,
          onFavoriteTap: () => _toggleFavorite(item),
          onCartTap: () => _addToCart(item),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(product: item),
              ),
            );
          },
        );
      },
    );
  }
}

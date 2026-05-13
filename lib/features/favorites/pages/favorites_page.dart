import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../home/pages/product_detail_page.dart';
import '../../home/services/product_repository.dart';
import '../../home/services/pet_repository.dart';
import '../services/favorite_repository.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductItem> _favoriteProducts = [];
  List<PetItem> _favoritePets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final products = await FavoriteRepository.instance.listFavoriteProducts();
      final pets = await FavoriteRepository.instance.listFavoritePets();
      if (mounted) {
        setState(() {
          _favoriteProducts = products;
          _favoritePets = pets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  Future<bool> _confirmRemove(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá "$name" khỏi danh sách yêu thích?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthSession.instance.currentUserId.value;

    if (userId == null) {
      return Container(
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_border, size: 80, color: AppColors.textLight),
                const SizedBox(height: 16),
                const Text('Vui lòng đăng nhập để xem yêu thích'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                    if (mounted) _loadFavorites();
                  },
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Sản phẩm', icon: Icon(Icons.shopping_bag_outlined)),
                Tab(text: 'Thú cưng', icon: Icon(Icons.pets)),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProductList(),
                        _buildPetList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_favoriteProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Chưa có sản phẩm yêu thích'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _favoriteProducts.length,
        itemBuilder: (context, index) {
          final item = _favoriteProducts[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.background,
                  child: const Icon(Icons.image_outlined, color: AppColors.textLight),
                ),
              ),
              title: Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatPrice(item.price)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final ok = await _confirmRemove(item.productName);
                  if (ok) {
                    await FavoriteRepository.instance.removeProductFavorite(item.productId);
                    _loadFavorites();
                  }
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(product: item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPetList() {
    if (_favoritePets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Chưa có thú cưng yêu thích'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _favoritePets.length,
        itemBuilder: (context, index) {
          final item = _favoritePets[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(Icons.pets, color: AppColors.textLight),
              ),
              title: Text(item.petName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.species),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final ok = await _confirmRemove(item.petName);
                  if (ok) {
                    await FavoriteRepository.instance.removePetFavorite(item.petId);
                    _loadFavorites();
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

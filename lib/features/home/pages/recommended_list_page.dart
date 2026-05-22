import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../widgets/pet_card.dart';
import '../widgets/product_card.dart';
import '../../pet_detail/pages/pet_detail_page.dart';
import '../../product_detail/pages/product_detail_page.dart';
import '../services/product_repository.dart';
import '../services/pet_repository.dart';
import '../models/recommended_item.dart';

/// Trang hiển thị danh sách gợi ý (nhận trực tiếp từ HomePage).
class RecommendedListPage extends StatefulWidget {
  final List<RecommendedItem> items;

  const RecommendedListPage({super.key, required this.items});

  @override
  State<RecommendedListPage> createState() => _RecommendedListPageState();
}

class _RecommendedListPageState extends State<RecommendedListPage> {
  Set<int> _favoriteProductIds = {};
  Set<int> _favoritePetIds = {};
  String _filter = 'Tất cả'; // 'Tất cả', 'Sản phẩm', 'Thú cưng'

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final results = await Future.wait([
        FavoriteRepository.instance.listFavoriteProducts(),
        FavoriteRepository.instance.listFavoritePets(),
      ]);
      if (!mounted) return;
      setState(() {
        _favoriteProductIds = (results[0] as List<ProductItem>)
            .map((e) => e.productId)
            .toSet();
        _favoritePetIds = (results[1] as List<PetItem>)
            .map((e) => e.petId)
            .toSet();
      });
    } catch (_) {}
  }

  List<RecommendedItem> get _filteredItems {
    if (_filter == 'Tất cả') return widget.items;
    if (_filter == 'Sản phẩm') {
      return widget.items
          .where((item) => item.kind == RecommendedKind.product)
          .toList();
    }
    // 'Thú cưng'
    return widget.items
        .where((item) => item.kind == RecommendedKind.pet)
        .toList();
  }

  Future<void> _ensureLoggedIn() async {
    if (AuthSession.instance.currentUserId.value != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _addProductToCart(ProductItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addProductToCart(productId: item.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _addPetToCart(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: item.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thú cưng vào giỏ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _toggleProductFavorite(ProductItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
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

  Future<void> _togglePetFavorite(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.togglePetFavorite(item.petId);
      setState(() {
        if (_favoritePetIds.contains(item.petId)) {
          _favoritePetIds.remove(item.petId);
        } else {
          _favoritePetIds.add(item.petId);
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
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gợi ý cho bạn'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Text(
                'Chưa có gợi ý nào cho bạn',
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
            )
          : Column(
              children: [
                // ── Filter chips ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sản phẩm'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Thú cưng'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Grid ──────────────────────────────────────────
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      if (item.kind == RecommendedKind.product) {
                        final product = item.product!;
                        return ProductCard(
                          item: product,
                          isFavorited:
                              _favoriteProductIds.contains(product.productId),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailPage(product: product),
                            ),
                          ),
                          onFavoriteTap: () =>
                              _toggleProductFavorite(product),
                          onCartTap: () => _addProductToCart(product),
                        );
                      } else {
                        final pet = item.pet!;
                        return PetCard(
                          item: pet,
                          compact: true,
                          isFavorited:
                              _favoritePetIds.contains(pet.petId),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PetDetailPage(pet: pet),
                            ),
                          ),
                          onFavoriteTap: () => _togglePetFavorite(pet),
                          onCartTap: () => _addPetToCart(pet),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.textLight,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

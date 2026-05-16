import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../home/pages/product_detail_page.dart';
import '../../home/pages/pet_detail_page.dart';
import '../../home/services/product_repository.dart';
import '../../home/services/pet_repository.dart';
import '../../home/widgets/product_card.dart';
import '../../home/widgets/pet_card.dart';
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

  // Batch delete state
  bool _batchDeleteMode = false;
  final Set<int> _selectedProductIds = {};
  final Set<int> _selectedPetIds = {};

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

  void _toggleBatchDeleteMode() {
    setState(() {
      _batchDeleteMode = !_batchDeleteMode;
      if (!_batchDeleteMode) {
        _selectedProductIds.clear();
        _selectedPetIds.clear();
      }
    });
  }

  void _toggleProductSelection(int productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _togglePetSelection(int petId) {
    setState(() {
      if (_selectedPetIds.contains(petId)) {
        _selectedPetIds.remove(petId);
      } else {
        _selectedPetIds.add(petId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final isProductTab = _tabController.index == 0;
    final selectedIds =
        isProductTab ? _selectedProductIds : _selectedPetIds;

    if (selectedIds.isEmpty) return;

    final count = selectedIds.length;
    final label = isProductTab ? 'sản phẩm' : 'thú cưng';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(

        content: Text('Bạn có muốn bỏ thích $count $label khỏi danh sách yêu thích?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (isProductTab) {
        for (final id in selectedIds) {
          await FavoriteRepository.instance.removeProductFavorite(id);
        }
      } else {
        for (final id in selectedIds) {
          await FavoriteRepository.instance.removePetFavorite(id);
        }
      }
      _selectedProductIds.clear();
      _selectedPetIds.clear();
      _batchDeleteMode = false;
      await _loadFavorites();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xoá: $e')),
        );
      }
    }
  }

  Future<void> _removeSingleProduct(ProductItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá "${item.productName}" khỏi danh sách yêu thích?'),
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

    if (confirmed == true) {
      await FavoriteRepository.instance.removeProductFavorite(item.productId);
      _loadFavorites();
    }
  }

  Future<void> _removeSinglePet(PetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá "${item.petName}" khỏi danh sách yêu thích?'),
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

    if (confirmed == true) {
      await FavoriteRepository.instance.removePetFavorite(item.petId);
      _loadFavorites();
    }
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
                const Icon(Icons.favorite_border,
                    size: 80, color: AppColors.textLight),
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
            // TabBar with trash icon on the right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textLight,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(
                          text: 'Phụ kiện',
                          icon: Icon(Icons.shopping_bag_outlined),
                        ),
                        Tab(
                          text: 'Thú cưng',
                          icon: Icon(Icons.pets),
                        ),
                      ],
                    ),
                  ),
                  // Trash bin icon for batch delete
                  IconButton(
                    icon: Icon(
                      _batchDeleteMode
                          ? Icons.close
                          : Icons.delete_outline,
                      color: _batchDeleteMode
                          ? AppColors.accent
                          : AppColors.textLight,
                    ),
                    onPressed: _toggleBatchDeleteMode,
                    tooltip: _batchDeleteMode ? 'Huỷ chọn' : 'Xoá hàng loạt',
                  ),
                ],
              ),
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
            // Batch delete action bar at bottom
            if (_batchDeleteMode)
              _buildBatchDeleteBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDeleteBar() {
    final isProductTab = _tabController.index == 0;
    final selectedCount =
        isProductTab ? _selectedProductIds.length : _selectedPetIds.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Đã chọn $selectedCount ${isProductTab ? 'sản phẩm' : 'thú cưng'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  if (isProductTab) {
                    _selectedProductIds.clear();
                  } else {
                    _selectedPetIds.clear();
                  }
                });
              },
              child: const Text('Bỏ chọn'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: selectedCount > 0 ? _deleteSelected : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Bỏ thích'),
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
            Icon(Icons.favorite_border,
                size: 64, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Chưa có phụ kiện yêu thích'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _favoriteProducts.length,
        itemBuilder: (context, index) {
          final item = _favoriteProducts[index];
          return _buildProductCard(item);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductItem item) {
    if (_batchDeleteMode) {
      final isSelected = _selectedProductIds.contains(item.productId);
      return Stack(
        children: [
          // ProductCard without heart icon
          ProductCard(
            item: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: item),
                ),
              );
            },
            onCartTap: () {
              // Navigate to cart or add to cart
            },
          ),
          // Checkbox overlay for batch selection
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _toggleProductSelection(item.productId),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textLight,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      )
                    : const SizedBox(
                        width: 20,
                        height: 20,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    // Normal mode: ProductCard without heart icon
    return ProductCard(
      item: item,
      showFavoriteIcon: false,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: item),
          ),
        );
      },
      onCartTap: () {
        // Navigate to cart or add to cart
      },
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
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _favoritePets.length,
        itemBuilder: (context, index) {
          final item = _favoritePets[index];
          return _buildPetCard(item);
        },
      ),
    );
  }

  Widget _buildPetCard(PetItem item) {
    if (_batchDeleteMode) {
      final isSelected = _selectedPetIds.contains(item.petId);
      return Stack(
        children: [
          // PetCard in compact mode without heart icon
          PetCard(
            item: item,
            compact: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetDetailPage(pet: item),
                ),
              );
            },
            onCartTap: () {
              // Navigate to cart or add to cart
            },
          ),
          // Checkbox overlay for batch selection
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _togglePetSelection(item.petId),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textLight,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      )
                    : const SizedBox(
                        width: 20,
                        height: 20,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    // Normal mode: PetCard without heart icon
    return PetCard(
      item: item,
      compact: true,
      showFavoriteIcon: false,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PetDetailPage(pet: item),
          ),
        );
      },
      onCartTap: () {
        // Navigate to cart or add to cart
      },
    );

  }
}

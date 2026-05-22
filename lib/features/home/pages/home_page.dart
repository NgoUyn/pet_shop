import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
import '../../../core/services/product_provider.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../../../core/utils/price_helper.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../cart/pages/checkout_page.dart';
import '../../favorites/services/favorite_repository.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';
import '../services/recommendation_service.dart';
import '../models/recommended_item.dart';
import '../widgets/pet_card.dart';
import '../widgets/product_card.dart';
import 'pet_list_page.dart';
import '../../pet_detail/pages/pet_detail_page.dart';
import '../../product_detail/pages/product_detail_page.dart';
import 'shop_list_page.dart';
import 'recommended_list_page.dart';
import 'image_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _homeDataFuture;
  String _selectedPetFilter = 'Tất cả';
  String _selectedProductFilter = 'Thức ăn';
  Set<int> _favoriteProductIds = {};
  Set<int> _favoritePetIds = {};
  List<RecommendedItem> _suggestedItems = [];
  List<int> _recommendedProductIds = [];
  List<int> _recommendedPetIds = [];

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
    // Listen to providers for automatic UI refresh
    PetProvider.instance.addListener(_onDataChanged);
    ProductProvider.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    PetProvider.instance.removeListener(_onDataChanged);
    ProductProvider.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {
        _homeDataFuture = _loadHomeData();
      });
    }
  }

  Future<_HomeData> _loadHomeData() async {
    final results = await Future.wait([
      ProductRepository.instance.listActiveProducts(limit: 50),
      Future.value(PetProvider.instance.pets),
      FavoriteRepository.instance.listFavoriteProducts(),
      FavoriteRepository.instance.listFavoritePets(),
      // Gọi API recommendation server
      RecommendationService.instance.getRecommendations(
        userId: AuthSession.instance.currentUserId.value,
        limit: 50,
      ),
    ]);
    _favoriteProductIds = (results[2] as List<ProductItem>)
        .map((item) => item.productId)
        .toSet();
    _favoritePetIds = (results[3] as List<PetItem>)
        .map((item) => item.petId)
        .toSet();
    final recResult = results[4] as RecommendationResult;
    _recommendedProductIds = recResult.productIds;
    _recommendedPetIds = recResult.petIds;
    _suggestedItems = _buildSuggestedItems(
      results[0] as List<ProductItem>,
      results[1] as List<PetItem>,
    );
    return _HomeData(
      products: results[0] as List<ProductItem>,
      pets: results[1] as List<PetItem>,
    );
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
          const SnackBar(content: Text('Đã thêm vào giỏ hàng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e.toString().replaceAll('StateError: ', ''))));
    }
  }

  Future<void> _toggleProductFavorite(ProductItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance
          .toggleProductFavorite(item.productId);
      setState(() {
        if (_favoriteProductIds.contains(item.productId)) {
          _favoriteProductIds.remove(item.productId);
        } else {
          _favoriteProductIds.add(item.productId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e.toString().replaceAll('StateError: ', ''))));
    }
  }

  Future<void> _addPetToCart(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: item.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm thú cưng vào giỏ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e.toString().replaceAll('StateError: ', ''))));
    }
  }

  void _buyProduct(ProductItem item) {
    _ensureLoggedIn().then((_) {
      if (!mounted || AuthSession.instance.currentUserId.value == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutPage(
            directItem: CartProductEntry(
              cartItemId: 0,
              productId: item.productId,
              petId: null,
              productName: item.productName,
              imageUrl: item.imageUrl,
              unitPrice: item.price,
              quantity: 1,
              addedAt: DateTime.now(),
              stockQuantity: item.stockQuantity,
            ),
          ),
        ),
      );
    });
  }

  void _buyPet(PetItem item) {
    _ensureLoggedIn().then((_) {
      if (!mounted || AuthSession.instance.currentUserId.value == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutPage(
            directItem: CartProductEntry(
              cartItemId: 0,
              productId: null,
              petId: item.petId,
              productName: item.petName,
              imageUrl: item.imageUrl,
              unitPrice: item.price ?? 0,
              quantity: 1,
              addedAt: DateTime.now(),
              stockQuantity: 1,
            ),
          ),
        ),
      );
    });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e.toString().replaceAll('StateError: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        await PetProvider.instance.reload();
        setState(() {
          _homeDataFuture = _loadHomeData();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── BANNER ────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.accentLight,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: CloudinaryHelper.getBannerImage('banner1'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.accentLight,
                        child: const Center(
                            child: Icon(Icons.pets, size: 50, color: AppColors.accent)),
                      ),
                    ),
                  ),
                  // (Image search moved to header camera icon)
                ],
              ),
            ),

            FutureBuilder<_HomeData>(
              future: _homeDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  );
                }
                final data = snapshot.data;
                if (data == null) return const SizedBox();

                final filteredPets = _filterPets(data.pets, _selectedPetFilter);
                final filteredProducts =
                    _filterProducts(data.products, _selectedProductFilter);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Gợi ý cho bạn ──────────────────────────────
                    _buildSectionHeader(
                      'Gợi ý cho bạn',
                      onAction: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => RecommendedListPage(items: _suggestedItems))),
                    ),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _suggestedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                          width: 165,
                          child: _buildSuggestionCard(_suggestedItems[index]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Thú cưng nổi bật ───────────────────────────
                    _buildSectionHeader(
                      'Thú cưng nổi bật',
                      onAction: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PetListPage())),
                    ),
                    _buildPetFilterRow(),
                    const SizedBox(height: 16),
                    if (filteredPets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: min(6, filteredPets.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, index) => PetCard(
                            item: filteredPets[index],
                            compact: true,
                            isFavorited: _favoritePetIds.contains(filteredPets[index].petId),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PetDetailPage(pet: filteredPets[index]),
                              ),
                            ),
                            onFavoriteTap: () => _togglePetFavorite(filteredPets[index]),
                            onCartTap: () => _addPetToCart(filteredPets[index]),
                            onBuyTap: () => _buyPet(filteredPets[index]),
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Chưa có thú cưng phù hợp'),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Phụ kiện nổi bật ───────────────────────────
                    _buildSectionHeader(
                      'Phụ kiện nổi bật',
                      onAction: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ShopListPage())),
                    ),
                    _buildProductFilterRow(),
                    const SizedBox(height: 16),
                    if (filteredProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: min(6, filteredProducts.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, index) => ProductCard(
                            item: filteredProducts[index],
                            isFavorited: _favoriteProductIds.contains(filteredProducts[index].productId),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailPage(product: filteredProducts[index]),
                              ),
                            ),
                            onFavoriteTap: () => _toggleProductFavorite(filteredProducts[index]),
                            onCartTap: () => _addProductToCart(filteredProducts[index]),
                            onBuyTap: () => _buyProduct(filteredProducts[index]),
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Chưa có sản phẩm phù hợp'),
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {required VoidCallback onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Times New Roman',
              color: AppColors.cardTextDark,
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 15,
                fontFamily: 'Times New Roman',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────────────────
  Widget _buildPetFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(_selectedPetFilter, 'Tất cả',
              (v) => setState(() => _selectedPetFilter = v)),
          _buildChip(_selectedPetFilter, 'Chó',
              (v) => setState(() => _selectedPetFilter = v)),
          _buildChip(_selectedPetFilter, 'Mèo',
              (v) => setState(() => _selectedPetFilter = v)),
        ],
      ),
    );
  }

  Widget _buildProductFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(_selectedProductFilter, 'Thức ăn',
              (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Phụ kiện',
              (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Thuốc',
              (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Vệ sinh',
              (v) => setState(() => _selectedProductFilter = v)),
        ],
      ),
    );
  }

  Widget _buildChip(
      String selected, String label, ValueChanged<String> onTap) {
    final isSelected = selected == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: InkWell(
          onTap: () => onTap(label),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.cardTextGray,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'Times New Roman',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Suggestion Card (horizontal scroll) ───────────────────────────────
  Widget _buildSuggestionCard(RecommendedItem item) {
    final bool isPet = item.kind == RecommendedKind.pet;

    if (isPet) {
      return PetCard(
        item: item.pet!,
        compact: true,
        isFavorited: _favoritePetIds.contains(item.pet!.petId),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PetDetailPage(pet: item.pet!)),
        ),
        onFavoriteTap: () => _togglePetFavorite(item.pet!),
        onCartTap: () => _addPetToCart(item.pet!),
        onBuyTap: () => _buyPet(item.pet!),
      );
    }

    return ProductCard(
      item: item.product!,
      isFavorited: _favoriteProductIds.contains(item.product!.productId),
      showFavoriteIcon: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: item.product!),
        ),
      ),
      onFavoriteTap: () => _toggleProductFavorite(item.product!),
      onCartTap: () => _addProductToCart(item.product!),
      onBuyTap: () => _buyProduct(item.product!),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  List<RecommendedItem> _buildSuggestedItems(
      List<ProductItem> products, List<PetItem> pets) {
    final productMap = {for (final p in products) p.productId: p};
    final petMap = {for (final p in pets) p.petId: p};

    // Lấy sản phẩm từ server recommend trước (tối đa 30)
    final result = <RecommendedItem>[];
    for (final id in _recommendedProductIds) {
      final product = productMap[id];
      if (product != null && result.length < 30) {
        result.add(RecommendedItem.product(product));
      }
    }

    // Nếu chưa đủ 30, thêm thú cưng cho đủ
    if (result.length < 30) {
      for (final id in _recommendedPetIds) {
        final pet = petMap[id];
        if (pet != null && result.length < 30) {
          result.add(RecommendedItem.pet(pet));
        }
      }
    }

    // Nếu có recommend từ server, dùng nó
    if (result.isNotEmpty) {
      return result;
    }

    // Fallback: shuffle ngẫu nhiên, lấy tối đa 30
    final items = <RecommendedItem>[
      ...products.map(RecommendedItem.product),
      ...pets.map(RecommendedItem.pet),
    ]..shuffle();
    return items.take(min(30, items.length)).toList();
  }

  List<PetItem> _filterPets(List<PetItem> items, String filter) {
    if (filter == 'Tất cả') return items;
    return items
        .where((item) =>
            item.species.toLowerCase().contains(filter.toLowerCase()))
        .toList();
  }

  List<ProductItem> _filterProducts(List<ProductItem> items, String filter) {
    if (filter == 'Thức ăn') {
      return items
          .where((item) =>
              item.productName.toLowerCase().contains('hạt') ||
              item.productName.toLowerCase().contains('pate'))
          .toList();
    }
    if (filter == 'Vòng') {
      return items
          .where((item) =>
              item.productName.toLowerCase().contains('vòng') ||
              item.productName.toLowerCase().contains('dây'))
          .toList();
    }
    if (filter == 'Thuốc') {
      return items
          .where((item) =>
              item.productName.toLowerCase().contains('thuốc') ||
              item.productName.toLowerCase().contains('vitamin'))
          .toList();
    }
    if (filter == 'Vệ sinh') {
      return items
          .where((item) =>
              item.productName.toLowerCase().contains('tắm') ||
              item.productName.toLowerCase().contains('vệ sinh'))
          .toList();
    }
    return items;
  }
}

// ── Supporting classes ────────────────────────────────────────────────────

class _HomeData {
  final List<ProductItem> products;
  final List<PetItem> pets;
  const _HomeData({required this.products, required this.pets});
}

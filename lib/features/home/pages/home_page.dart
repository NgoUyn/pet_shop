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
import '../../favorites/services/favorite_repository.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';
import '../widgets/pet_card.dart';
import 'pet_list_page.dart';
import 'pet_detail_page.dart';
import 'product_detail_page.dart';
import 'shop_list_page.dart';

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
  List<_RecommendedItem> _suggestedItems = [];

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
    ]);
    _favoriteProductIds = (results[2] as List<ProductItem>)
        .map((item) => item.productId)
        .toSet();
    _favoritePetIds = (results[3] as List<PetItem>)
        .map((item) => item.petId)
        .toSet();
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

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}tr';
    }
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ';
  }

  String _petEmoji(String species) {
    final s = species.toLowerCase();
    if (s.contains('chó') || s.contains('dog')) return '🐕';
    if (s.contains('mèo') || s.contains('cat')) return '🐱';
    if (s.contains('hamster')) return '🐹';
    return '🐾';
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: CloudinaryHelper.getBannerImage('banner1'),
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.accentLight,
                    child: const Center(
                        child: Icon(Icons.pets, size: 50, color: AppColors.accent)),
                  ),
                ),
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
                          MaterialPageRoute(builder: (_) => const ShopListPage())),
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

                    // ── Sản phẩm gợi ý ─────────────────────────────
                    _buildSectionHeader(
                      'Sản phẩm gợi ý',
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
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (context, index) =>
                              _buildProductTile(filteredProducts[index]),
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
          _buildChip(_selectedPetFilter, 'Hamster',
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

  // ── Product Tile (3-col grid) ─────────────────────────────────────────
  Widget _buildProductTile(ProductItem item) {
    final isFavorited = _favoriteProductIds.contains(item.productId);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: item)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheHeight: 400,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.image, size: 40),
                      ),
                    )
                  : Text(_productEmoji(item.productName),
                      style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.productName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Times New Roman',
              color: AppColors.cardTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleProductFavorite(item),
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: isFavorited ? AppColors.accent : AppColors.cardTextGray,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _addProductToCart(item),
                icon: const Icon(Icons.add_shopping_cart_outlined,
                    size: 20, color: AppColors.cardTextGray),
              ),
            ],
          ),
          Text(
            _formatPrice(item.price),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
              fontFamily: 'Times New Roman',
            ),
          ),
        ],
      ),
    );
  }

  String _productEmoji(String name) {
    final value = name.toLowerCase();
    if (value.contains('pate') || value.contains('hạt')) return '🥩';
    if (value.contains('vòng') || value.contains('dây')) return '🦴';
    if (value.contains('tắm') || value.contains('vệ sinh')) return '🛁';
    return '🧸';
  }

  // ── Suggestion Card (horizontal scroll) ───────────────────────────────
  Widget _buildSuggestionCard(_RecommendedItem item) {
    String name = '';
    String priceStr = '-';
    String? imageUrl;
    bool isPet = item.kind == _RecommendedKind.pet;
    final isProductFavorited =
        !isPet && _favoriteProductIds.contains(item.product!.productId);
    final isPetFavorited =
        isPet && _favoritePetIds.contains(item.pet!.petId);

    if (isPet) {
      name = item.pet!.petName;
      priceStr =
          item.pet!.price != null ? formatPrice(item.pet!.price!) : '-';
    } else {
      name = item.product!.productName;
      priceStr = _formatPrice(item.product!.price);
      imageUrl = item.product!.imageUrl;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (isPet) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => PetDetailPage(pet: item.pet!)));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailPage(product: item.product!)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: isPet
                    ? Container(
                        color: AppColors.accentLight,
                        alignment: Alignment.center,
                        child: Text(
                          _petEmoji(item.pet!.species),
                          style: const TextStyle(fontSize: 44),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheHeight: 400,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Times New Roman',
                      color: AppColors.cardTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceStr,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => isPet
                            ? _togglePetFavorite(item.pet!)
                            : _toggleProductFavorite(item.product!),
                        icon: Icon(
                          isPet
                              ? (isPetFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border)
                              : (isProductFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border),
                          size: 20,
                          color: (isPet ? isPetFavorited : isProductFavorited)
                              ? AppColors.accent
                              : AppColors.cardTextGray,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => isPet
                            ? _addPetToCart(item.pet!)
                            : _addProductToCart(item.product!),
                        icon: const Icon(Icons.add_shopping_cart_outlined,
                            size: 20, color: AppColors.cardTextGray),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  List<_RecommendedItem> _buildSuggestedItems(
      List<ProductItem> products, List<PetItem> pets) {
    final items = <_RecommendedItem>[
      ...products.map(_RecommendedItem.product),
      ...pets.map(_RecommendedItem.pet),
    ]..shuffle();
    return items.take(min(5, items.length)).toList();
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
    if (filter == 'Phụ kiện') {
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

class _TagPill extends StatelessWidget {
  const _TagPill(
      {required this.label,
      required this.color,
      required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HomeData {
  final List<ProductItem> products;
  final List<PetItem> pets;
  const _HomeData({required this.products, required this.pets});
}

enum _RecommendedKind { product, pet }

class _RecommendedItem {
  final _RecommendedKind kind;
  final ProductItem? product;
  final PetItem? pet;

  _RecommendedItem.product(this.product)
      : kind = _RecommendedKind.product,
        pet = null;
  _RecommendedItem.pet(this.pet)
      : kind = _RecommendedKind.pet,
        product = null;
}

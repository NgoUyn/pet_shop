import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../../pet_detail/pages/customer_pet_detail_page.dart';
import '../../product_detail/pages/product_detail_page.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';

class ProductSearchDelegate extends SearchDelegate<ProductItem?> {
  final List<ProductItem> _allProducts = [];
  final List<PetItem> _allPets = [];
  bool _loaded = false;
  Set<int> _favoriteProductIds = {};
  Set<int> _favoritePetIds = {};

  @override
  String get searchFieldLabel => 'Tìm sản phẩm, thú cưng...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textLight),
        border: InputBorder.none,
      ),
    );
  }

  Future<void> _ensureLoaded(BuildContext context) async {
    if (_loaded) return;
    try {
      final db = await AppDatabase.instance;

      // Load products
      final productRows = await db.query('Product',
        where: 'IsActive = 1',
        orderBy: 'ProductName ASC',
      );
      _allProducts.addAll(productRows.map(ProductItem.fromRow));

      // Load pets
      final petRows = await db.query('Pet',
        where: 'IsActive = 1',
        orderBy: 'PetName ASC',
      );
      _allPets.addAll(petRows.map(PetItem.fromRow));

      // Load favorites
      _favoriteProductIds = (await FavoriteRepository.instance.listFavoriteProducts())
          .map((item) => item.productId).toSet();
      _favoritePetIds = (await FavoriteRepository.instance.listFavoritePets())
          .map((item) => item.petId).toSet();
    } catch (e) {
      // ignore load error
    }
    _loaded = true;
    showSuggestions(context);
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '$bufferđ';
  }

  /// Lọc tên sản phẩm để hiển thị đề xuất (chỉ lấy tên, không trùng)
  List<String> _suggestNames(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    final names = <String>{};

    for (final p in _allProducts) {
      if (p.productName.toLowerCase().contains(q)) {
        names.add(p.productName);
      }
    }
    for (final p in _allPets) {
      if (p.petName.toLowerCase().contains(q)) {
        names.add(p.petName);
      }
    }

    final sorted = names.toList();
    // Ưu tiên tên bắt đầu bằng query
    sorted.sort((a, b) {
      final aStarts = a.toLowerCase().startsWith(q);
      final bStarts = b.toLowerCase().startsWith(q);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.compareTo(b);
    });
    return sorted;
  }

  /// Lọc kết quả chi tiết (sản phẩm + thú cưng)
  List<_SearchResultItem> _filterResults(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();

    final results = <_SearchResultItem>[];

    for (final p in _allProducts) {
      if (p.productName.toLowerCase().contains(q)) {
        results.add(_SearchResultItem(product: p));
      }
    }

    for (final p in _allPets) {
      if (p.petName.toLowerCase().contains(q) ||
          p.species.toLowerCase().contains(q)) {
        results.add(_SearchResultItem(pet: p));
      }
    }

    return results;
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (!_loaded) {
      _ensureLoaded(context);
      return const Center(child: CircularProgressIndicator());
    }

    final suggestions = _suggestNames(query);

    if (query.isEmpty) {
      return const Center(
        child: Text('Nhập tên sản phẩm hoặc thú cưng để tìm kiếm',
            style: TextStyle(color: AppColors.textLight)),
      );
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Text('Không tìm thấy "$query"',
            style: const TextStyle(color: AppColors.textLight)),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, i) {
        final name = suggestions[i];
        return ListTile(
          leading: const Icon(Icons.search, color: AppColors.textLight),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            // Gán tên được chọn vào query và chuyển sang kết quả
            query = name;
            showResults(context);
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (!_loaded) {
      _ensureLoaded(context);
      return const Center(child: CircularProgressIndicator());
    }
    final results = _filterResults(query);
    return _buildResultGrid(context, results);
  }

  // ── GridView giống ShopListPage ──────────────────────────────────────

  Widget _buildResultGrid(BuildContext context, List<_SearchResultItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('Không tìm thấy "$query"',
            style: const TextStyle(color: AppColors.textLight)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isPet = item.pet != null;

        if (isPet) {
          return _buildPetCard(context, item.pet!);
        }
        return _buildProductCard(context, item.product!);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, ProductItem product) {
    final isFavorited = _favoriteProductIds.contains(product.productId);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
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
                    _buildImage(product.imageUrl),
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
                              onTap: () => _toggleProductFavorite(context, product),
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
                              onTap: () => _addProductToCart(context, product),
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
                    product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatPrice(product.price),
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
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, PetItem pet) {
    final isFavorited = _favoritePetIds.contains(pet.petId);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerPetDetailPage(pet: pet),

          ),
        );
      },
      child: Container(
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
                child: Container(
                  color: const Color(0xFFF9FAFB),
                  alignment: Alignment.center,
                  child: Text(
                    pet.species.contains('Chó') || pet.species.contains('chó')
                        ? '🐕'
                        : pet.species.contains('Mèo') || pet.species.contains('mèo')
                            ? '🐱'
                            : '🐾',
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.petName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet.species,
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.price != null ? _formatPrice(pet.price!) : 'Liên hệ',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _togglePetFavorite(context, pet),
                        child: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: isFavorited ? Colors.red : AppColors.textDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _addPetToCart(context, pet),
                        child: const Icon(
                          Icons.add_shopping_cart_outlined,
                          color: AppColors.textDark,
                          size: 20,
                        ),
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

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _ensureLoggedIn(BuildContext context) async {
    if (AuthSession.instance.currentUserId.value != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _addProductToCart(BuildContext context, ProductItem item) async {
    await _ensureLoggedIn(context);
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addProductToCart(productId: item.productId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _addPetToCart(BuildContext context, PetItem item) async {
    await _ensureLoggedIn(context);
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: item.petId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thú cưng vào giỏ'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _toggleProductFavorite(BuildContext context, ProductItem item) async {
    await _ensureLoggedIn(context);
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.toggleProductFavorite(item.productId);
      if (_favoriteProductIds.contains(item.productId)) {
        _favoriteProductIds.remove(item.productId);
      } else {
        _favoriteProductIds.add(item.productId);
      }
      // Rebuild results to reflect favorite change
      showResults(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _togglePetFavorite(BuildContext context, PetItem item) async {
    await _ensureLoggedIn(context);
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.togglePetFavorite(item.petId);
      if (_favoritePetIds.contains(item.petId)) {
        _favoritePetIds.remove(item.petId);
      } else {
        _favoritePetIds.add(item.petId);
      }
      // Rebuild results to reflect favorite change
      showResults(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    if (query.isNotEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];
    }
    return [];
  }
}

class _SearchResultItem {
  final ProductItem? product;
  final PetItem? pet;

  _SearchResultItem({this.product, this.pet});
}

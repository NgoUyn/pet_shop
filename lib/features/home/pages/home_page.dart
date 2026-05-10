import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';
import 'pet_list_page.dart';
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

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final results = await Future.wait([
      ProductRepository.instance.listActiveProducts(limit: 50),
      PetRepository.instance.listActivePets(limit: 50),
    ]);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm vào giỏ hàng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))));
    }
  }

  Future<void> _toggleProductFavorite(ProductItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.toggleProductFavorite(item.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm vào danh sách yêu thích')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))));
    }
  }

  Future<void> _addPetToCart(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: item.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thú cưng vào giỏ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))));
    }
  }

  Future<void> _togglePetFavorite(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.togglePetFavorite(item.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật danh sách yêu thích')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))));
    }
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}tr';
    }
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _homeDataFuture = _loadHomeData();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BANNER
            Container(
              margin: const EdgeInsets.all(16),
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFF3F4F6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: CloudinaryHelper.getBannerImage('banner1'),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFFFF9C4),
                    child: const Center(child: Icon(Icons.image, size: 50, color: Colors.orange)),
                  ),
                ),
              ),
            ),

            FutureBuilder<_HomeData>(
              future: _homeDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }
                final data = snapshot.data;
                if (data == null) return const SizedBox();

                final suggestedItems = _buildSuggestedItems(data.products, data.pets);
                final filteredPets = _filterPets(data.pets, _selectedPetFilter);
                final filteredProducts = _filterProducts(data.products, _selectedProductFilter);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gợi ý Section
                    _buildSectionHeader(
                      'Gợi ý cho bạn',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopListPage())),
                    ),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(width: 165, child: _buildSuggestionCard(suggestedItems[index])),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Thú cưng nổi bật Section
                    _buildSectionHeader(
                      'Thú cưng nổi bật',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PetListPage())),
                    ),
                    _buildPetFilterRow(),
                    const SizedBox(height: 16),
                    if (filteredPets.isNotEmpty)
                      ...filteredPets.take(3).map(_buildPetRow)
                    else
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Chưa có thú cưng phù hợp'))),

                    const SizedBox(height: 24),

                    // Sản phẩm gợi ý Section (3 cột như ảnh mẫu)
                    _buildSectionHeader(
                      'Sản phẩm gợi ý',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopListPage())),
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
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (context, index) => _buildProductTile(filteredProducts[index]),
                        ),
                      )
                    else
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Chưa có sản phẩm phù hợp'))),
                    
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

  List<_RecommendedItem> _buildSuggestedItems(List<ProductItem> products, List<PetItem> pets) {
    final items = <_RecommendedItem>[
      ...products.map(_RecommendedItem.product),
      ...pets.map(_RecommendedItem.pet),
    ]..shuffle();
    return items.take(min(5, items.length)).toList();
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman')),
          TextButton(onPressed: onAction, child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFF5BAA7C), fontSize: 16, fontFamily: 'Times New Roman'))),
        ],
      ),
    );
  }

  Widget _buildPetFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(_selectedPetFilter, 'Tất cả', (v) => setState(() => _selectedPetFilter = v)),
          _buildChip(_selectedPetFilter, 'Chó', (v) => setState(() => _selectedPetFilter = v)),
          _buildChip(_selectedPetFilter, 'Mèo', (v) => setState(() => _selectedPetFilter = v)),
          _buildChip(_selectedPetFilter, 'Hamster', (v) => setState(() => _selectedPetFilter = v)),
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
          _buildChip(_selectedProductFilter, 'Thức ăn', (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Phụ kiện', (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Thuốc', (v) => setState(() => _selectedProductFilter = v)),
          _buildChip(_selectedProductFilter, 'Vệ sinh', (v) => setState(() => _selectedProductFilter = v)),
        ],
      ),
    );
  }

  Widget _buildChip(String selected, String label, ValueChanged<String> onTap) {
    final isSelected = selected == label;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5BAA7C) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF666666), fontSize: 16, fontFamily: 'Times New Roman')),
        ),
      ),
    );
  }

  Widget _buildPetRow(PetItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
            child: const Center(child: Text('🐕', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${item.petName} — ${item.description?.contains('đực') == true ? "đực" : "cái"}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Times New Roman'))),
                    Text(item.price != null ? _formatPrice(item.price!) : '-', style: const TextStyle(fontSize: 18, color: Color(0xFF5BAA7C), fontFamily: 'Times New Roman')),
                  ],
                ),
                const SizedBox(height: 4),
                Text('3 tháng · Tiêm phòng đủ · Sổ y bạ', style: const TextStyle(color: Color(0xFF666666), fontSize: 14, fontFamily: 'Times New Roman')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _togglePetFavorite(item),
                      icon: const Icon(Icons.favorite_border),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _addPetToCart(item),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: const [
                    _TagPill(label: 'Thân thiện', color: Color(0xFFD8EEE4), textColor: Color(0xFF3E7C63)),
                    _TagPill(label: 'Đã tẩy giun', color: Color(0xFFD8EEE4), textColor: Color(0xFF3E7C63)),
                    _TagPill(label: 'Còn 2 con', color: Color(0xFFF5E8C9), textColor: Color(0xFF8A6A23)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(ProductItem item) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: item))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: item.imageUrl!, errorWidget: (context, url, error) => const Icon(Icons.image, size: 40))
                  : Text(_productEmoji(item.productName), style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.productName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontFamily: 'Times New Roman')),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleProductFavorite(item),
                icon: const Icon(Icons.favorite_border, size: 20),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _addProductToCart(item),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
              ),
            ],
          ),
          Text(_formatPrice(item.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5BAA7C), fontFamily: 'Times New Roman')),
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

  Widget _buildSuggestionCard(_RecommendedItem item) {
    String name = '';
    String priceStr = '-';
    String? imageUrl;
    bool isPet = item.kind == _RecommendedKind.pet;

    if (isPet) {
      name = item.pet!.petName;
      priceStr = item.pet!.price != null ? _formatPrice(item.pet!.price!) : '-';
    } else {
      name = item.product!.productName;
      priceStr = _formatPrice(item.product!.price);
      imageUrl = item.product!.imageUrl;
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: isPet 
                ? Container(color: const Color(0xFFF9FAFB), alignment: Alignment.center, child: const Text('🐶', style: TextStyle(fontSize: 44)))
                : CachedNetworkImage(imageUrl: imageUrl ?? '', fit: BoxFit.cover, width: double.infinity, errorWidget: (_,__,___) => const Icon(Icons.image)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontFamily: 'Times New Roman')),
                const SizedBox(height: 4),
                Text(priceStr, style: const TextStyle(fontSize: 15, color: Color(0xFF5BAA7C), fontWeight: FontWeight.bold, fontFamily: 'Times New Roman')),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => isPet ? _togglePetFavorite(item.pet!) : _toggleProductFavorite(item.product!),
                      icon: const Icon(Icons.favorite_border, size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => isPet ? _addPetToCart(item.pet!) : _addProductToCart(item.product!),
                      icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PetItem> _filterPets(List<PetItem> items, String filter) {
    if (filter == 'Tất cả') return items;
    return items.where((item) => item.species.toLowerCase().contains(filter.toLowerCase())).toList();
  }

  List<ProductItem> _filterProducts(List<ProductItem> items, String filter) {
    if (filter == 'Thức ăn') return items.where((item) => item.productName.toLowerCase().contains('hạt') || item.productName.toLowerCase().contains('pate')).toList();
    if (filter == 'Phụ kiện') return items.where((item) => item.productName.toLowerCase().contains('vòng') || item.productName.toLowerCase().contains('dây')).toList();
    if (filter == 'Thuốc') return items.where((item) => item.productName.toLowerCase().contains('thuốc') || item.productName.toLowerCase().contains('vitamin')).toList();
    if (filter == 'Vệ sinh') return items.where((item) => item.productName.toLowerCase().contains('tắm') || item.productName.toLowerCase().contains('vệ sinh')).toList();
    return items;
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color, required this.textColor});
  final String label; final Color color; final Color textColor;
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Times New Roman')),
    );
  }
}

enum _RecommendedKind { product, pet }

class _RecommendedItem {
  _RecommendedItem._(this.kind, {this.product, this.pet});
  final _RecommendedKind kind;
  final ProductItem? product;
  final PetItem? pet;
  factory _RecommendedItem.product(ProductItem product) => _RecommendedItem._(_RecommendedKind.product, product: product);
  factory _RecommendedItem.pet(PetItem pet) => _RecommendedItem._(_RecommendedKind.pet, pet: pet);
}

class _HomeData {
  final List<ProductItem> products;
  final List<PetItem> pets;
  _HomeData({required this.products, required this.pets});
}

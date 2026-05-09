import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../services/pet_repository.dart';
import '../services/product_repository.dart';
import 'pet_list_page.dart';
import 'product_detail_page.dart';
import 'shop_list_page.dart';
import '../widgets/pet_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _homeDataFuture;
  String _selectedPetFilter = 'Tất cả';
  String _selectedProductFilter = 'Thức ăn';

  void _reloadHomeData() {
    if (!mounted) return;
    setState(() {
      _homeDataFuture = _loadHomeData();
    });
  }

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
    PetRepository.instance.changeToken.addListener(_reloadHomeData);
    ProductRepository.instance.changeToken.addListener(_reloadHomeData);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_reloadHomeData);
    ProductRepository.instance.changeToken.removeListener(_reloadHomeData);
    super.dispose();
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gợi ý Section
                    _buildSectionHeader(
                      'Gợi ý cho bạn',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopListPage())),
                    ),
                    SizedBox(
                      height: 248,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestedItems.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                          width: 172,
                          child: _buildHomeItemCard(suggestedItems[index]),
                        ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: min(4, filteredPets.length),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.74,
                          ),
                          itemBuilder: (context, index) => _buildPetCard(filteredPets[index]),
                        ),
                      )
                    else
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Chưa có thú cưng phù hợp'))),

                    const SizedBox(height: 24),

                    // Sản phẩm gợi ý Section
                    _buildSectionHeader(
                      'Sản phẩm gợi ý',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopListPage())),
                    ),
                    _buildProductFilterRow(),
                    const SizedBox(height: 16),
                    if (data.products.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: min(6, data.products.length),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (context, index) => _buildProductTile(data.products[index]),
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

  Widget _buildPetCard(PetItem item) {
    return PetCard(
      item: item,
      formatPrice: _formatPrice,
      onTap: () => showPetDetailSheet(context, item, _formatPrice),
    );
  }

  Widget _buildProductTile(ProductItem item) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: item))),
      child: _SquareHomeCard(
        image: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: item.imageUrl!, errorWidget: (context, url, error) => const Icon(Icons.image, size: 40))
            : Text(_productEmoji(item.productName), style: const TextStyle(fontSize: 40)),
        title: item.productName,
        subtitle: '',
        price: _formatPrice(item.price),
        badges: const [],
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

  Widget _buildHomeItemCard(_RecommendedItem item) {
    String name = '';
    String priceStr = '-';
    String? imageUrl;
    bool isPet = item.kind == _RecommendedKind.pet;
    List<_CardBadge> badges = const [];

    if (isPet) {
      name = item.pet!.petName;
      priceStr = item.pet!.price != null ? _formatPrice(item.pet!.price!) : '-';
      imageUrl = item.pet!.imageUrl;
      badges = [
        _CardBadge(label: item.pet!.age != null ? '${item.pet!.age} tháng' : 'Chưa có tuổi', isPrimary: true),
        _CardBadge(label: item.pet!.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun'),
        _CardBadge(label: item.pet!.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng'),
      ];
    } else {
      name = item.product!.productName;
      priceStr = _formatPrice(item.product!.price);
      imageUrl = item.product!.imageUrl;
    }

    return _SquareHomeCard(
      image: isPet
          ? _buildPreviewImage(imageUrl, fallback: const Center(child: Text('🐶', style: TextStyle(fontSize: 44))))
          : _buildPreviewImage(imageUrl, fallback: const Icon(Icons.image)),
      title: name,
      subtitle: isPet && item.pet!.species.isNotEmpty ? item.pet!.species : 'Phụ kiện',
      price: priceStr,
      badges: badges,
    );
  }

  Widget _buildPreviewImage(String? imageUrl, {double? width, double? height, required Widget fallback}) {
    final normalized = (imageUrl ?? '').trim();
    if (normalized.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF9FAFB),
        alignment: Alignment.center,
        child: fallback,
      );
    }

    final image = normalized.startsWith('http://') || normalized.startsWith('https://')
        ? CachedNetworkImage(
            imageUrl: normalized,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => fallback,
          )
        : Image.file(
            File(normalized),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );

    return image;
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

class _SquareHomeCard extends StatelessWidget {
  const _SquareHomeCard({required this.image, required this.title, required this.subtitle, required this.price, required this.badges});

  final Widget image;
  final String title;
  final String subtitle;
  final String price;
  final List<_CardBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              alignment: Alignment.center,
              child: FittedBox(fit: BoxFit.scaleDown, child: image),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontFamily: 'Times New Roman'),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontFamily: 'Times New Roman'),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF5BAA7C), fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: badges,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.label, this.accent, this.textColor, this.isPrimary = false});

  final String label;
  final Color? accent;
  final Color? textColor;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final background = accent ?? (isPrimary ? const Color(0xFFD8EEE4) : const Color(0xFFF5E8C9));
    final foreground = textColor ?? (isPrimary ? const Color(0xFF3E7C63) : const Color(0xFF8A6A23));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Times New Roman')),
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

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'optimized_network_image.dart';
import '../utils/cloudinary_transform.dart';
import '../db/app_database.dart';
import '../../features/home/services/pet_repository.dart';
import '../../features/home/services/product_repository.dart';
import '../../features/pet_detail/pages/pet_detail_page.dart';
import '../../features/product_detail/pages/product_detail_page.dart';

/// A bottom sheet that shows a hierarchical navigation menu.
/// Pets are grouped by species → breed, products are grouped by category.
class NavigationMenuSheet extends StatefulWidget {
  const NavigationMenuSheet({super.key});

  @override
  State<NavigationMenuSheet> createState() => _NavigationMenuSheetState();
}

class _NavigationMenuSheetState extends State<NavigationMenuSheet> {
  List<PetItem> _pets = [];
  List<ProductItem> _products = [];
  List<_CategoryInfo> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        PetRepository.instance.listActivePets(limit: 200),
        ProductRepository.instance.listActiveProducts(limit: 200),
        _loadCategories(),
      ]);

      if (!mounted) return;
      setState(() {
        _pets = results[0] as List<PetItem>;
        _products = results[1] as List<ProductItem>;
        _categories = results[2] as List<_CategoryInfo>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<List<_CategoryInfo>> _loadCategories() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('Category');
    return rows.map((row) {
      return _CategoryInfo(
        id: row['CategoryID'] as int,
        name: row['CategoryName'] as String,
        parentId: row['ParentCategoryID'] as int?,
      );
    }).toList();
  }

  /// Group pets by species, then by breed.
  Map<String, Map<String, List<PetItem>>> _groupPetsBySpeciesAndBreed() {
    final result = <String, Map<String, List<PetItem>>>{};
    for (final pet in _pets) {
      final species = pet.species.isNotEmpty ? pet.species : 'Khác';
      final breed = (pet.breed != null && pet.breed!.trim().isNotEmpty) ? pet.breed! : species;
      result.putIfAbsent(species, () => {});
      result[species]!.putIfAbsent(breed, () => []);
      result[species]![breed]!.add(pet);
    }
    return result;
  }

  /// Group products by category.
  Map<String, List<ProductItem>> _groupProductsByCategory() {
    final result = <String, List<ProductItem>>{};
    final categoryMap = {for (final c in _categories) c.id: c.name};
    for (final product in _products) {
      final catName = categoryMap[product.categoryId] ?? 'Danh mục ${product.categoryId}';
      result.putIfAbsent(catName, () => []);
      result[catName]!.add(product);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Danh mục',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        children: [
                          _buildSectionHeader(Icons.pets, 'Thú cưng', Colors.orange),
                          ..._buildPetMenuItems(),
                          const SizedBox(height: 8),
                          _buildSectionHeader(Icons.shopping_bag_outlined, 'Sản phẩm', AppColors.primary),
                          ..._buildProductMenuItems(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPetMenuItems() {
    final grouped = _groupPetsBySpeciesAndBreed();
    if (grouped.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Chưa có thú cưng', style: TextStyle(color: AppColors.textLight)),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final species = entry.key;
      final breeds = entry.value;
      final speciesIcon = species.contains('Chó') || species.contains('chó')
          ? '🐕'
          : species.contains('Mèo') || species.contains('mèo')
              ? '🐱'
              : '🐾';

      widgets.add(
        _buildExpansionTile(
          title: '$speciesIcon  $species',
          subtitle: '${breeds.length} giống',
          children: breeds.entries.map((breedEntry) {
            final breed = breedEntry.key;
            final pets = breedEntry.value;
            return _buildExpansionTile(
              title: breed,
              subtitle: '${pets.length} thú cưng',
              children: pets.map((pet) {
                return ListTile(
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: pet.imageUrl != null && pet.imageUrl!.isNotEmpty
                          ? OptimizedNetworkImage(imageUrl: pet.imageUrl!, size: CloudinaryImageSize.avatar, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.background,
                              child: const Icon(Icons.pets, color: AppColors.textLight),
                            ),
                    ),
                  ),
                  title: Text(pet.petName, style: const TextStyle(fontSize: 14)),
                  subtitle: pet.price != null
                      ? Text('${pet.price!.toStringAsFixed(0)}đ', style: const TextStyle(fontSize: 12, color: AppColors.primary))
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PetDetailPage(pet: pet)),
                    );
                  },
                );
              }).toList(),
            );
          }).toList(),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildProductMenuItems() {
    final grouped = _groupProductsByCategory();
    if (grouped.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Chưa có sản phẩm', style: TextStyle(color: AppColors.textLight)),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final catName = entry.key;
      final products = entry.value;

      final icon = catName.toLowerCase().contains('thức ăn') || catName.toLowerCase().contains('pate')
          ? '🍖'
          : catName.toLowerCase().contains('phụ kiện') || catName.toLowerCase().contains('vòng')
              ? '🎀'
              : '📦';

      widgets.add(
        _buildExpansionTile(
          title: '$icon  $catName',
          subtitle: '${products.length} sản phẩm',
          children: products.map((product) {
            return ListTile(
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? OptimizedNetworkImage(imageUrl: product.imageUrl!, size: CloudinaryImageSize.avatar, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.background,
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.textLight),
                        ),
                ),
              ),
              title: Text(product.productName, style: const TextStyle(fontSize: 14)),
              subtitle: Text('${product.price.toStringAsFixed(0)}đ', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
                );
              },
            );
          }).toList(),
        ),
      );
    }
    return widgets;
  }

  Widget _buildExpansionTile({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      childrenPadding: const EdgeInsets.only(left: 16),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight))
          : null,
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      children: children,
    );
  }
}

class _CategoryInfo {
  final int id;
  final String name;
  final int? parentId;

  _CategoryInfo({
    required this.id,
    required this.name,
    this.parentId,
  });
}

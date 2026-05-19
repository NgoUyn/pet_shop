import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../home/services/product_repository.dart';
import '../../home/services/pet_repository.dart';
import '../services/category_repository.dart';
import 'admin_product_form_page.dart';
import 'admin_pet_form_page.dart';

// ── Page ──────────────────────────────────────────────────────────────────

class AdminCategoryPage extends StatelessWidget {
  const AdminCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Danh mục'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          surfaceTintColor: AppColors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Phụ kiện', icon: Icon(Icons.shopping_bag_outlined)),
              Tab(text: 'Thú cưng', icon: Icon(Icons.pets_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProductCategoryTab(),
            _PetCategoryTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Phụ kiện (ProductSubCategory) ───────────────────────────────────

class _ProductCategoryTab extends StatefulWidget {
  const _ProductCategoryTab();
  @override
  State<_ProductCategoryTab> createState() => _ProductCategoryTabState();
}

class _ProductCategoryTabState extends State<_ProductCategoryTab> {
  ProductSubCategory? _selectedSubCat;
  List<ProductItem> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ProductRepository.instance.changeToken.addListener(_loadProducts);
  }

  @override
  void dispose() {
    ProductRepository.instance.changeToken.removeListener(_loadProducts);
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final prods = await ProductRepository.instance.listActiveProducts();
    if (!mounted) return;
    setState(() {
      _products = prods;
      _loadingProducts = false;
    });
  }

  Future<void> _addSubCat() async {
    final result = await _showNameDescDialog(context, title: 'Thêm loại phụ kiện');
    if (result == null) return;
    await CategoryRepository.instance.addSubCategory(
      subCategoryName: result.$1,
      description: result.$2,
    );
  }

  Future<void> _editSubCat(ProductSubCategory sub) async {
    final result = await _showNameDescDialog(context,
        title: 'Chỉnh sửa loại phụ kiện',
        initialName: sub.subCategoryName,
        initialDesc: sub.description);
    if (result == null) return;
    await CategoryRepository.instance.updateSubCategory(
      subCategoryId: sub.subCategoryId,
      subCategoryName: result.$1,
      description: result.$2,
    );
  }

  Future<void> _deleteSubCat(ProductSubCategory sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa loại phụ kiện'),
        content: Text('Xóa loại "${sub.subCategoryName}"?\nCác sản phẩm thuộc loại này sẽ không bị ảnh hưởng.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CategoryRepository.instance.deleteSubCategory(sub.subCategoryId);
    if (_selectedSubCat?.subCategoryId == sub.subCategoryId) {
      setState(() => _selectedSubCat = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductSubCategory>>(
      stream: CategoryRepository.instance.watchAllSubCategories(),
      builder: (context, snap) {
        final subCats = snap.data ?? [];

        final filtered = _selectedSubCat == null
            ? _products
            : _products
                .where((p) => p.subCategoryId == _selectedSubCat!.subCategoryId)
                .toList();

        return CustomScrollView(
          slivers: [
            // ── SubCategory chips + add button ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _Chip(
                              label: 'Tất cả',
                              selected: _selectedSubCat == null,
                              onTap: () => setState(() => _selectedSubCat = null),
                            ),
                            const SizedBox(width: 8),
                            ...subCats.map((s) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _Chip(
                                    label: s.subCategoryName,
                                    selected: _selectedSubCat?.subCategoryId == s.subCategoryId,
                                    onTap: () => setState(() => _selectedSubCat = s),
                                    onLongPress: () => _editSubCat(s),
                                    onDelete: () => _deleteSubCat(s),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddChipButton(label: 'Loại mới', onTap: _addSubCat),
                  ],
                ),
              ),
            ),

            // ── Product list ─────────────────────────────────────
            if (_loadingProducts)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text(
                        _selectedSubCat == null
                            ? 'Chưa có sản phẩm nào'
                            : 'Không có sản phẩm loại "${_selectedSubCat!.subCategoryName}"',
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final subName = subCats
                        .where((s) => s.subCategoryId == item.subCategoryId)
                        .map((s) => s.subCategoryName)
                        .firstOrNull ?? '';
                    return _ProductTile(
                      item: item,
                      categoryName: subName,
                      onTap: () async {
                        await Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => AdminProductFormPage(product: item),
                        ));
                        await _loadProducts();
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Tab: Thú cưng (PetBreedCategory) ─────────────────────────────────────

class _PetCategoryTab extends StatefulWidget {
  const _PetCategoryTab();
  @override
  State<_PetCategoryTab> createState() => _PetCategoryTabState();
}

class _PetCategoryTabState extends State<_PetCategoryTab> {
  static const List<String> _speciesList = ['Chó', 'Mèo', 'Khác'];
  String _selectedSpecies = 'Chó';
  PetBreed? _selectedBreed;
  List<PetItem> _pets = [];
  bool _loadingPets = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
    PetRepository.instance.changeToken.addListener(_loadPets);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_loadPets);
    super.dispose();
  }

  Future<void> _loadPets() async {
    final pets = await PetRepository.instance.listActivePets();
    if (!mounted) return;
    setState(() {
      _pets = pets;
      _loadingPets = false;
    });
  }

  Future<void> _addBreed() async {
    final result = await _showNameDescDialog(context,
        title: 'Thêm giống ${_selectedSpecies.toLowerCase()}');
    if (result == null) return;
    await CategoryRepository.instance.addBreed(
      species: _selectedSpecies,
      breedName: result.$1,
      description: result.$2,
    );
  }

  Future<void> _editBreed(PetBreed breed) async {
    final result = await _showNameDescDialog(context,
        title: 'Chỉnh sửa giống',
        initialName: breed.breedName,
        initialDesc: breed.description);
    if (result == null) return;
    await CategoryRepository.instance.updateBreed(
      breedId: breed.breedId,
      species: breed.species,
      breedName: result.$1,
      description: result.$2,
    );
  }

  Future<void> _deleteBreed(PetBreed breed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giống'),
        content: Text('Xóa giống "${breed.breedName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CategoryRepository.instance.deleteBreed(breed.breedId);
    if (_selectedBreed?.breedId == breed.breedId) {
      setState(() => _selectedBreed = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PetBreed>>(
      stream: CategoryRepository.instance.watchAllBreeds(),
      builder: (context, snap) {
        final allBreeds = snap.data ?? [];
        final breedsForSpecies =
            allBreeds.where((b) => b.species == _selectedSpecies && b.isActive).toList();

        final filteredPets = _pets.where((p) {
          if (p.species != _selectedSpecies) return false;
          if (_selectedBreed == null) return true;
          return (p.breed ?? '') == _selectedBreed!.breedName;
        }).toList();

        return CustomScrollView(
          slivers: [
            // ── Species tabs ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: _speciesList.map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(
                      label: s,
                      selected: _selectedSpecies == s,
                      onTap: () => setState(() {
                        _selectedSpecies = s;
                        _selectedBreed = null;
                      }),
                    ),
                  )).toList(),
                ),
              ),
            ),

            // ── Breed chips + add button ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _Chip(
                              label: 'Tất cả',
                              selected: _selectedBreed == null,
                              onTap: () => setState(() => _selectedBreed = null),
                            ),
                            const SizedBox(width: 8),
                            ...breedsForSpecies.map((b) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _Chip(
                                    label: b.breedName,
                                    selected: _selectedBreed?.breedId == b.breedId,
                                    onTap: () => setState(() => _selectedBreed = b),
                                    onLongPress: () => _editBreed(b),
                                    onDelete: () => _deleteBreed(b),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AddChipButton(label: 'Giống mới', onTap: _addBreed),
                  ],
                ),
              ),
            ),

            // ── Pet list ─────────────────────────────────────────
            if (_loadingPets)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (filteredPets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets_outlined, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      Text(
                        _selectedBreed == null
                            ? 'Chưa có $_selectedSpecies nào'
                            : 'Không có $_selectedSpecies giống "${_selectedBreed!.breedName}"',
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: filteredPets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = filteredPets[i];
                    return _PetTile(
                      item: item,
                      onTap: () async {
                        await Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => AdminPetFormPage(pet: item),
                        ));
                        await _loadPets();
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE7EAF0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 6, onDelete != null ? 4 : 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textDark,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.close, size: 14,
                        color: selected ? Colors.white70 : AppColors.textLight),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddChipButton extends StatelessWidget {
  const _AddChipButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item, required this.categoryName, required this.onTap});
  final ProductItem item;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 52, height: 52, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 52, height: 52, color: AppColors.background),
                        errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: AppColors.background,
                            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textLight)),
                      )
                    : Container(width: 52, height: 52, color: AppColors.background,
                        child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textLight)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (categoryName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(categoryName, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(width: 8),
                        Text('Tồn: ${item.stockQuantity}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.item, required this.onTap});
  final PetItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 52, height: 52, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 52, height: 52, color: AppColors.background),
                        errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: AppColors.background,
                            child: const Icon(Icons.pets, color: AppColors.textLight)),
                      )
                    : Container(width: 52, height: 52, color: AppColors.background,
                        child: const Icon(Icons.pets, color: AppColors.textLight)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.petName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                          child: Text('${item.species}${item.breed != null ? " • ${item.breed}" : ""}',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.isActive ? const Color(0xFFD8EEE4) : const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isActive ? 'Đang bán' : 'Ngưng',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: item.isActive ? const Color(0xFF3E7C63) : const Color(0xFFB42318)),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Generic name+desc dialog ──────────────────────────────────────────────

Future<(String, String?)?> _showNameDescDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String? initialDesc,
}) async {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final descCtrl = TextEditingController(text: initialDesc ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<(String, String?)?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, (
              nameCtrl.text.trim(),
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            ));
          },
          child: Text(initialName == null ? 'Thêm' : 'Lưu'),
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  descCtrl.dispose();
  return result;
}

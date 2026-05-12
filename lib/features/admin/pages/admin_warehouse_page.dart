import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../home/pages/pet_detail_page.dart';
import '../../home/pages/product_detail_page.dart';
import '../../home/services/pet_repository.dart';
import '../../home/services/product_repository.dart';

String _formatMoney(double value) {
  final formatted = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < formatted.length; i++) {
    final fromEnd = formatted.length - i;
    buffer.write(formatted[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '${buffer.toString()}đ';
}

class AdminWarehousePage extends StatefulWidget {
  const AdminWarehousePage({super.key});

  @override
  State<AdminWarehousePage> createState() => _AdminWarehousePageState();
}

class _AdminWarehousePageState extends State<AdminWarehousePage> {
  late Future<_WarehouseData> _future;
  String _query = '';
  String _selectedFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _future = _WarehouseData.load();
  }

  void _reload() {
    setState(() {
      _future = _WarehouseData.load();
    });
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (sheetContext) {
        var currentValue = _selectedFilter;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Bộ lọc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    value: 'Tất cả',
                    groupValue: currentValue,
                    onChanged: (value) => setSheetState(() => currentValue = value ?? 'Tất cả'),
                    title: const Text('Tất cả'),
                  ),
                  RadioListTile<String>(
                    value: 'Thú cưng',
                    groupValue: currentValue,
                    onChanged: (value) => setSheetState(() => currentValue = value ?? 'Tất cả'),
                    title: const Text('Thú cưng'),
                  ),
                  RadioListTile<String>(
                    value: 'Phụ kiện',
                    groupValue: currentValue,
                    onChanged: (value) => setSheetState(() => currentValue = value ?? 'Tất cả'),
                    title: const Text('Phụ kiện'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, currentValue),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedFilter = selected;
    });
  }

  Widget _buildStatCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  Widget _buildListItem(_WarehouseItem item) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => item.kind == _WarehouseKind.pet
                  ? PetDetailPage(pet: item.pet!)
                  : ProductDetailPage(product: item.product!, showAdminActions: true),
            ),
          );
          if (changed == true && mounted) {
            _reload();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl == null || item.imageUrl!.trim().isEmpty
                    ? Icon(item.kind == _WarehouseKind.pet ? Icons.pets_outlined : Icons.shopping_bag_outlined, color: AppColors.textLight, size: 34)
                    : Image.network(
                        item.imageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(item.kind == _WarehouseKind.pet ? Icons.pets_outlined : Icons.shopping_bag_outlined, color: AppColors.textLight, size: 34),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: AppColors.textLight),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.kind == _WarehouseKind.pet ? const Color(0xFFEAF3FF) : const Color(0xFFF0F7EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.kind == _WarehouseKind.pet ? 'Thú cưng' : 'Phụ kiện',
                            style: TextStyle(
                              color: item.kind == _WarehouseKind.pet ? const Color(0xFF2F80ED) : const Color(0xFF3E7C63),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item.trailingText, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WarehouseData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _WarehouseData.empty();
        final searchQuery = _query.trim().toLowerCase();

        final filteredItems = data.items.where((item) {
          final matchesFilter = _selectedFilter == 'Tất cả' || (_selectedFilter == 'Thú cưng' && item.kind == _WarehouseKind.pet) || (_selectedFilter == 'Phụ kiện' && item.kind == _WarehouseKind.product);
          final matchesSearch = searchQuery.isEmpty || item.searchText.contains(searchQuery);
          return matchesFilter && matchesSearch;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (data.lowStockCount > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cảnh báo tồn kho: ${data.lowStockCount} phụ kiện sắp hết hàng',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data.lowStockCount > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.pets_outlined,
                        value: data.totalPets.toString(),
                        label: 'Tổng thú cưng',
                        color: const Color(0xFF2F80ED),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.shopping_bag_outlined,
                        value: data.totalProducts.toString(),
                        label: 'Tổng phụ kiện',
                        color: const Color(0xFF3E7C63),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openFilterSheet,
                      icon: const Icon(Icons.tune),
                      label: const Text('Bộ lọc'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('Tất cả'),
                            _buildFilterChip('Thú cưng'),
                            _buildFilterChip('Phụ kiện'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Danh sách kho', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (filteredItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Không có dữ liệu phù hợp.')),
                  )
                else
                  ...filteredItems.map(_buildListItem),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _WarehouseKind { pet, product }

class _WarehouseItem {
  _WarehouseItem.pet({required PetItem pet})
      : pet = pet,
        product = null,
        kind = _WarehouseKind.pet,
        title = pet.petName,
        subtitle = '${pet.species} • ${pet.isActive ? 'Đang bán' : 'Ngừng bán'}',
        trailingText = pet.price == null ? 'Chưa có giá' : _formatMoney(pet.price!),
        imageUrl = pet.imageUrl,
        searchText = '${pet.petName} ${pet.species} ${pet.description ?? ''} ${pet.gender ?? ''}'.toLowerCase();

  _WarehouseItem.product({required ProductItem product})
      : pet = null,
        product = product,
        kind = _WarehouseKind.product,
        title = product.productName,
        subtitle = 'Tồn kho: ${product.stockQuantity} • ${product.isActive ? 'Đang bán' : 'Ngừng bán'}',
        trailingText = _formatMoney(product.price),
        imageUrl = product.imageUrl,
        searchText = '${product.productName} ${product.description ?? ''}'.toLowerCase();

  final PetItem? pet;
  final ProductItem? product;
  final _WarehouseKind kind;
  final String title;
  final String subtitle;
  final String trailingText;
  final String? imageUrl;
  final String searchText;

}

class _WarehouseData {
  _WarehouseData({required this.totalPets, required this.totalProducts, required this.lowStockCount, required this.items});

  final int totalPets;
  final int totalProducts;
  final int lowStockCount;
  final List<_WarehouseItem> items;

  static _WarehouseData empty() => _WarehouseData(totalPets: 0, totalProducts: 0, lowStockCount: 0, items: const []);

  static Future<_WarehouseData> load() async {
    final pets = await PetRepository.instance.listActivePets(limit: 500);
    final products = await ProductRepository.instance.listActiveProducts(limit: 500);

    final lowStockCount = products.where((item) => item.stockQuantity <= 5).length;
    final items = <_WarehouseItem>[
      ...pets.map((item) => _WarehouseItem.pet(pet: item)),
      ...products.map((item) => _WarehouseItem.product(product: item)),
    ]..sort((a, b) {
        final aDate = a.pet?.createdAt ?? a.product!.createdAt;
        final bDate = b.pet?.createdAt ?? b.product!.createdAt;
        return bDate.compareTo(aDate);
      });

    return _WarehouseData(
      totalPets: pets.length,
      totalProducts: products.length,
      lowStockCount: lowStockCount,
      items: items,
    );
  }
}

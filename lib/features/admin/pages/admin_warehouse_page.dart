import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/optimized_network_image.dart';
import '../../../core/utils/cloudinary_transform.dart';
import '../../../core/utils/price_helper.dart';
import '../../../core/utils/vnd_currency_input_formatter.dart';
import '../../pet_detail/pages/pet_detail_page.dart';
import '../../product_detail/pages/admin_product_detail.dart';
import '../../home/services/pet_repository.dart';
import '../../home/services/product_repository.dart';
import '../services/promotion_repository.dart';
import 'admin_pet_form_page.dart';
import 'admin_product_form_page.dart';

class AdminWarehousePage extends StatefulWidget {
  const AdminWarehousePage({super.key});

  @override
  State<AdminWarehousePage> createState() => _AdminWarehousePageState();
}

class _AdminWarehousePageState extends State<AdminWarehousePage> {
  late Future<_WarehouseData> _future;
  late Future<List<_WarehouseItem>> _soldFuture;
  String _query = '';
  String _selectedFilter = 'Tất cả';
  String _selectedTab = 'Kho';
  String _soldFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _future = _WarehouseData.load();
    _soldFuture = _loadSoldItems();
    PetRepository.instance.changeToken.addListener(_reload);
    ProductRepository.instance.changeToken.addListener(_reload);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_reload);
    ProductRepository.instance.changeToken.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _WarehouseData.load();
      _soldFuture = _loadSoldItems();
    });
  }

  Future<List<_WarehouseItem>> _loadSoldItems() async {
    final items = <_WarehouseItem>[];
    final seenKeys = <String>{};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderStatus', isEqualTo: 'Completed')
          .limit(500)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final list = (data['items'] as List<dynamic>?) ?? [];

        for (final raw in list) {
          final item = Map<String, dynamic>.from(raw as Map);
          final productId = (item['productId'] as num?)?.toInt();
          final petId = (item['petId'] as num?)?.toInt();
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

          if (productId != null) {
            final key = 'prod_$productId';
            if (seenKeys.contains(key)) continue;
            seenKeys.add(key);
            items.add(_WarehouseItem.soldProduct(
              soldProductId: productId,
              productName: (item['productName'] as String?) ?? 'Sản phẩm',
              price: (item['unitPrice'] as num?)?.toDouble() ?? 0,
              quantity: quantity,
            ));
          } else if (petId != null) {
            final key = 'pet_$petId';
            if (seenKeys.contains(key)) continue;
            seenKeys.add(key);
            items.add(_WarehouseItem.soldPet(
              soldPetId: petId,
              petName: (item['petName'] as String?) ?? 'Thú cưng',
              price: (item['unitPrice'] as num?)?.toDouble() ?? 0,
              quantity: quantity,
            ));
          }
        }
      }
    } catch (e) {
      print('_loadSoldItems Firestore error: $e');
    }

    items.sort((a, b) => b.title.compareTo(a.title));
    return items;
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
      if (_selectedTab == 'Kho') {
        _selectedFilter = selected;
      } else {
        _soldFilter = selected;
      }
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
          if (_selectedTab == 'Đã bán') {
            // Read-only: fetch full item from repository and open detail without admin actions
            try {
              if (item.soldProductId != null) {
                final prod = await ProductRepository.instance.getProductById(item.soldProductId!);
                if (prod != null && mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminProductDetailPage(product: prod, readOnly: true),
                    ),
                  );
                }
              } else if (item.soldPetId != null) {
                final pet = await PetRepository.instance.getPetById(item.soldPetId!);
                if (pet != null && mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PetDetailPage(pet: pet, showAdminActions: false),
                    ),
                  );
                }
              }
            } catch (_) {}
            return;
          }

          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => item.kind == _WarehouseKind.pet
                  ? PetDetailPage(pet: item.pet!, showAdminActions: true)
                  : AdminProductDetailPage(product: item.product!),
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
                    : OptimizedNetworkImage(
                        imageUrl: item.imageUrl!.trim(),
                        size: CloudinaryImageSize.avatar,
                        fit: BoxFit.cover,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Tab bar: Kho / Đã bán / Ưu đãi ─────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                _buildTabChip('Kho', Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                _buildTabChip('Đã bán', Icons.sell_outlined),
                const SizedBox(width: 8),
                _buildTabChip('Ưu đãi', Icons.local_offer_outlined),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _selectedTab == 'Kho'
                ? _buildWarehouseTab()
                : _selectedTab == 'Đã bán'
                    ? _buildSoldTab()
                    : _buildPromotionsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, IconData icon) {
    final isSelected = _selectedTab == label;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textLight),
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedTab = label;
          _query = '';
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.12),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildWarehouseTab() {
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

        return RefreshIndicator(
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
                          'Cảnh báo tồn kho: ${data.lowStockCount} mặt hàng sắp hết hàng',
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
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (!mounted) return;
                      Widget page;
                      if (value == 'pet') {
                        page = const AdminPetFormPage();
                      } else {
                        page = const AdminProductFormPage();
                      }
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                      if (added == true && mounted) {
                        _reload();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value == 'pet'
                                  ? 'Đã thêm thú cưng mới'
                                  : 'Đã thêm phụ kiện mới',
                            ),
                          ),
                        );
                      }
                    },
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pet',
                        child: ListTile(
                          leading: Icon(Icons.pets_outlined, color: Color(0xFF2F80ED)),
                          title: Text('Thú cưng'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'product',
                        child: ListTile(
                          leading: Icon(Icons.shopping_bag_outlined, color: Color(0xFF3E7C63)),
                          title: Text('Phụ kiện'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm mới sản phẩm'),
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
        );
      },
    );
  }

  Widget _buildSoldTab() {
    return FutureBuilder<List<_WarehouseItem>>(
      future: _soldFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final searchQuery = _query.trim().toLowerCase();

        final filtered = items.where((item) {
          final matchesFilter = _soldFilter == 'Tất cả' ||
              (_soldFilter == 'Thú cưng' && item.kind == _WarehouseKind.pet) ||
              (_soldFilter == 'Phụ kiện' && item.kind == _WarehouseKind.product);
          final matchesSearch = searchQuery.isEmpty || item.searchText.contains(searchQuery);
          return matchesFilter && matchesSearch;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pets_outlined,
                      value: items.where((i) => i.kind == _WarehouseKind.pet).length.toString(),
                      label: 'Thú cưng đã bán',
                      color: const Color(0xFF2F80ED),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.shopping_bag_outlined,
                      value: items.where((i) => i.kind == _WarehouseKind.product).length.toString(),
                      label: 'Phụ kiện đã bán',
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
                    hintText: 'Tìm kiếm sản phẩm đã bán...',
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
                    label: Text('Bộ lọc: $_soldFilter'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Danh sách đã bán (${filtered.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Chưa có mặt hàng nào được bán.')),
                )
              else
                ...filtered.map(_buildListItem),
            ],
          ),
        );
      },
    );
  }
  // ── Promotions Tab ──────────────────────────────────────────────────

  Widget _buildPromotionsTab() {
    return FutureBuilder<List<PromotionItemV2>>(
      future: PromotionRepository.instance.listAll(),
      builder: (context, snapshot) {
        final promotions = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddPromotionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Thêm ưu đãi'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.local_offer_outlined,
                        value: promotions.length.toString(),
                        label: 'Tổng ưu đãi',
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.check_circle_outline,
                        value: promotions.where((p) => p.isActive).length.toString(),
                        label: 'Đang hoạt động',
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Danh sách ưu đãi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (promotions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Chưa có ưu đãi nào. Nhấn nút + để tạo mới.')),
                  )
                else
                  ...promotions.map((promo) => _buildPromotionCard(promo)),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromotionCard(PromotionItemV2 promo) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isActive = promo.isActive;

    return Card(
      elevation: 0,
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: isActive ? const Color(0xFF27AE60) : AppColors.textLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.code,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isActive ? AppColors.textDark : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        promo.description,
                        style: TextStyle(
                          color: isActive ? AppColors.textDark : AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle switch for active/inactive
                if (!promo.isExpired)
                  Switch(
                    value: promo.status == 'Active',
                    activeTrackColor: const Color(0xFF27AE60),
                    onChanged: (_) async {
                      await PromotionRepository.instance.toggleStatus(promo.promotionId);
                      if (mounted) setState(() {});
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Hết hạn',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _promoInfoChip('Giảm', '${promo.discountPercent.toStringAsFixed(0)}%'),
                const SizedBox(width: 8),
                _promoInfoChip('Giảm tối đa', formatPrice(promo.maxDiscount)),
                const SizedBox(width: 8),
                _promoInfoChip('Đơn tối thiểu', formatPrice(promo.minOrderValue)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: promo.isExpired ? Colors.red : AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  'HSD: ${dateFormat.format(promo.expiryDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: promo.isExpired ? Colors.red : AppColors.textLight,
                    fontWeight: promo.isExpired ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _showAddPromotionDialog() async {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final percentCtrl = TextEditingController();
    final maxDiscountCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Thêm ưu đãi mới'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Mã ưu đãi (VD: PET20)'),
                      validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập mã' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Nội dung (VD: Giảm 20%)'),
                      maxLines: 2,
                      validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập nội dung' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: percentCtrl,
                      decoration: const InputDecoration(labelText: '% giảm (VD: 20)', suffixText: '%'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Vui lòng nhập % giảm';
                        final val = double.tryParse(v!);
                        if (val == null || val <= 0 || val > 100) return 'Từ 1-100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: maxDiscountCtrl,
                      decoration: const InputDecoration(labelText: 'Giảm tối đa (VNĐ)', hintText: '0 = không giới hạn'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [VndCurrencyInputFormatter()],
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Vui lòng nhập';
                        if (parseVndAmount(v) == null) return 'Số không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: minOrderCtrl,
                      decoration: const InputDecoration(labelText: 'Giá trị đơn tối thiểu (VNĐ)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [VndCurrencyInputFormatter()],
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Vui lòng nhập';
                        if (parseVndAmount(v) == null) return 'Số không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ngày hết hạn'),
                        child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
              FilledButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await PromotionRepository.instance.create(
                        code: codeCtrl.text.trim().toUpperCase(),
                        description: descCtrl.text.trim(),
                        discountPercent: double.parse(percentCtrl.text.trim()),
                        maxDiscount: (parseVndAmount(maxDiscountCtrl.text) ?? 0).toDouble(),
                        minOrderValue: (parseVndAmount(minOrderCtrl.text) ?? 0).toDouble(),
                        expiryDate: selectedDate,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  }
                },
                child: const Text('Thêm & Thông báo'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm ưu đãi mới')),
      );
    }
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
        trailingText = pet.price == null ? 'Chưa có giá' : formatPrice(pet.price!),
        imageUrl = pet.imageUrl,
        searchText = '${pet.petName} ${pet.species} ${pet.description ?? ''} ${pet.gender ?? ''}'.toLowerCase(),
        soldProductId = null,
        soldPetId = null;

  _WarehouseItem.product({required ProductItem product})
      : pet = null,
        product = product,
        kind = _WarehouseKind.product,
        title = product.productName,
        subtitle = 'Tồn kho: ${product.stockQuantity} • ${product.isActive ? 'Đang bán' : 'Ngừng bán'}',
        trailingText = formatPrice(product.price),
        imageUrl = product.imageUrl,
        searchText = '${product.productName} ${product.description ?? ''}'.toLowerCase(),
        soldProductId = null,
        soldPetId = null;

  _WarehouseItem.soldProduct({
    required this.soldProductId,
    required String productName,
    required double price,
    String? imageUrl,
    int quantity = 1,
  })  : pet = null,
        product = null,
        kind = _WarehouseKind.product,
        title = productName,
        subtitle = 'Đã bán $quantity cái',
        trailingText = formatPrice(price),
        imageUrl = imageUrl,
        searchText = productName.toLowerCase(),
        soldPetId = null;

  _WarehouseItem.soldPet({
    required this.soldPetId,
    required String petName,
    String? species,
    required double price,
    String? imageUrl,
    int quantity = 1,
  })  : pet = null,
        product = null,
        kind = _WarehouseKind.pet,
        title = petName,
        subtitle = 'Đã bán $quantity ${species != null ? '• $species' : ''}',
        trailingText = formatPrice(price),
        imageUrl = imageUrl,
        searchText = '$petName ${species ?? ''}'.toLowerCase(),
        soldProductId = null;

  final PetItem? pet;
  final ProductItem? product;
  final _WarehouseKind kind;
  final String title;
  final String subtitle;
  final String trailingText;
  final String? imageUrl;
  final String searchText;
  final int? soldProductId;
  final int? soldPetId;

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

    final lowStockCount =
        products.where((item) => item.stockQuantity <= 5).length +
        pets.where((item) => item.stockQuantity <= 5).length;
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

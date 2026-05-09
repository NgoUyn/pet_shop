import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../../core/widgets/main_wrapper.dart';
import '../../auth/services/auth_repository.dart';
import '../../home/services/product_repository.dart';
import '../../orders/services/order_repository.dart';
import 'admin_pet_form_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  final List<_SectionData> _sections = const [
    _SectionData('Tổng quan', Icons.dashboard_outlined, Icons.dashboard),
    _SectionData('Phân tích', Icons.analytics_outlined, Icons.analytics),
    _SectionData('Đơn hàng', Icons.receipt_long_outlined, Icons.receipt_long),
    _SectionData('Người dùng', Icons.groups_outlined, Icons.groups),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        title: Text(
          _sections[_selectedIndex].label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Bộ lọc',
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: const NetworkImage(
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=160&q=80',
              ),
              onBackgroundImageError: (_, __) {},
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          _AnalyticsTab(),
          _OrdersTab(),
          _UsersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        destinations: _sections
            .map(
              (section) => NavigationDestination(
                icon: Icon(section.icon),
                selectedIcon: Icon(section.activeIcon),
                label: section.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionData {
  const _SectionData(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<_AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _AdminStats.load();
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;
    setState(() {
      _statsFuture = _AdminStats.load();
    });
    await _statsFuture;
  }

  Future<void> _handleSettingsTap() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất admin'),
        content: const Text('Bạn có muốn đăng xuất và quay về giao diện khách hàng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) {
      return;
    }

    await AuthRepository.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
      (route) => false,
    );
  }

  Future<void> _openAddItemPopup() async {
    final db = await AppDatabase.instance;
    final categoryRows = await db.query(
      'Category',
      columns: ['CategoryID', 'CategoryName'],
      orderBy: 'CategoryName ASC',
    );

    final categories = categoryRows
        .map(
          (row) => _CategoryChoice(
            id: row['CategoryID'] as int,
            name: (row['CategoryName'] as String?) ?? '',
          ),
        )
        .where((choice) => choice.name.isNotEmpty)
        .toList();

    final accessoryCategories = categories.where((c) => c.name.contains('Phụ kiện') || c.name.contains('Thức ăn')).toList();
    final accessoryDefaultCategoryId = accessoryCategories.isNotEmpty ? accessoryCategories.first.id : (categories.isNotEmpty ? categories.first.id : null);

    final formKey = GlobalKey<FormState>();
    final petNameCtrl = TextEditingController();
    final speciesCtrl = TextEditingController();
    String selectedPetGender = 'Cái';
    final petPriceCtrl = TextEditingController();
    final petDescCtrl = TextEditingController();
    final productNameCtrl = TextEditingController();
    final productPriceCtrl = TextEditingController();
    final productStockCtrl = TextEditingController(text: '1');
    final productDescCtrl = TextEditingController();
    final productImageCtrl = TextEditingController();

    _AddItemType? selectedType;
    int? selectedAccessoryCategoryId = accessoryDefaultCategoryId;
    bool saving = false;

    Future<void> submitForm(StateSetter setSheetState) async {
      final now = DateTime.now().toIso8601String();

      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }

      if (selectedType == _AddItemType.accessory && selectedAccessoryCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có danh mục phụ kiện để lưu sản phẩm')),
        );
        return;
      }

      try {
        setSheetState(() {
          saving = true;
        });

        if (selectedType == _AddItemType.pet) {
          await db.insert('Pet', {
            'CustomerID': null,
            'PetName': petNameCtrl.text.trim(),
            'Species': speciesCtrl.text.trim(),
            'Gender': selectedPetGender,
            'Description': petDescCtrl.text.trim().isEmpty ? null : petDescCtrl.text.trim(),
            'Price': double.parse(petPriceCtrl.text.trim()),
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          });
        } else {
          await ProductRepository.instance.addProduct(
            categoryId: selectedAccessoryCategoryId!,
            productName: productNameCtrl.text.trim(),
            price: double.parse(productPriceCtrl.text.trim()),
            stockQuantity: int.parse(productStockCtrl.text.trim()),
            description: productDescCtrl.text.trim().isEmpty ? null : productDescCtrl.text.trim(),
            imageUrl: productImageCtrl.text.trim().isEmpty ? null : productImageCtrl.text.trim(),
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop();
        await _refreshStats();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm sản phẩm thành công')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thêm sản phẩm: $e')),
        );
      } finally {
        if (mounted) {
          setSheetState(() {
            saving = false;
          });
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildTypeChooser() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thêm sản phẩm',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SheetChoiceCard(
                    title: 'Thú cưng',
                    subtitle: 'Thêm pet mới vào hệ thống',
                    icon: Icons.pets,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminPetFormPage()),
                      );
                      if (!mounted) return;
                      if (added == true) {
                        await _refreshStats();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã lưu thú cưng mới')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _SheetChoiceCard(
                    title: 'Phụ kiện',
                    subtitle: 'Thêm phụ kiện cho thú cưng',
                    icon: Icons.shopping_bag_outlined,
                    onTap: () {
                      setSheetState(() {
                        selectedType = _AddItemType.accessory;
                      });
                    },
                  ),
                ],
              );
            }

            Widget buildPetForm() {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => selectedType = null),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'Thêm thú cưng',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: petNameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên thú cưng', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên thú cưng' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: speciesCtrl,
                      decoration: const InputDecoration(labelText: 'Loài', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập loài' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPetGender,
                      decoration: const InputDecoration(labelText: 'Giới tính', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Đực', child: Text('Đực')),
                        DropdownMenuItem(value: 'Cái', child: Text('Cái')),
                        DropdownMenuItem(value: 'Chưa xác định', child: Text('Chưa xác định')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setSheetState(() {
                                selectedPetGender = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: petPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá bán', border: OutlineInputBorder()),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Vui lòng nhập giá hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: petDescCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving ? null : () => submitForm(setSheetState),
                        child: saving ? const CircularProgressIndicator() : const Text('Lưu thú cưng'),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildAccessoryForm() {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => selectedType = null),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'Thêm phụ kiện',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: productNameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên phụ kiện', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên phụ kiện' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: productPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Giá bán', border: OutlineInputBorder()),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Vui lòng nhập giá hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: productStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số lượng tồn kho', border: OutlineInputBorder()),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Vui lòng nhập số lượng hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAccessoryCategoryId,
                      decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                      items: accessoryCategories
                          .map(
                            (choice) => DropdownMenuItem<int>(
                              value: choice.id,
                              child: Text(choice.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          selectedAccessoryCategoryId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Vui lòng chọn danh mục' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: productImageCtrl,
                      decoration: const InputDecoration(labelText: 'Đường dẫn ảnh', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: productDescCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving ? null : () => submitForm(setSheetState),
                        child: saving ? const CircularProgressIndicator() : const Text('Lưu phụ kiện'),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: selectedType == null ? buildTypeChooser() : selectedType == _AddItemType.pet ? buildPetForm() : buildAccessoryForm(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    petNameCtrl.dispose();
    speciesCtrl.dispose();
    petPriceCtrl.dispose();
    petDescCtrl.dispose();
    productNameCtrl.dispose();
    productPriceCtrl.dispose();
    productStockCtrl.dispose();
    productDescCtrl.dispose();
    productImageCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không tải được dashboard: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final stats = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refreshStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeroCard(stats: stats),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    title: 'Tổng sản phẩm',
                    value: stats.totalProducts.toString(),
                    subtitle: 'Tổng sản phẩm',
                    icon: Icons.inventory_2_outlined,
                    dark: true,
                    progress: 0.72,
                  ),
                  _MetricCard(
                    title: 'Tổng đơn hàng',
                    value: stats.totalOrders.toString(),
                    subtitle: 'Đơn hàng',
                    icon: Icons.receipt_long_outlined,
                    progress: 0.46,
                  ),
                  _MetricCard(
                    title: 'Tổng khách hàng',
                    value: stats.totalCustomers.toString(),
                    subtitle: 'Khách hàng',
                    icon: Icons.groups_outlined,
                    progress: 0.61,
                  ),
                  _MetricCard(
                    title: 'Doanh thu',
                    value: _formatMoney(stats.totalRevenue),
                    subtitle: 'Doanh thu',
                    icon: Icons.payments_outlined,
                    progress: 0.83,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionHeader(
                title: 'Doanh thu',
                action: _PillAction(label: 'Tuần này', selected: true),
              ),
              const SizedBox(height: 12),
              _ChartCard(
                height: 210,
                child: _LineChart(
                  primaryValues: stats.weeklyRevenue,
                  secondaryValues: stats.weeklyOrders,
                ),
              ),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Thao tác nhanh'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _QuickActionCard(icon: Icons.add_box_outlined, label: 'Thêm sản phẩm', onTap: _openAddItemPopup)),
                  const SizedBox(width: 12),
                  const Expanded(child: _QuickActionCard(icon: Icons.local_shipping_outlined, label: 'Giao đơn')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: _QuickActionCard(icon: Icons.people_alt_outlined, label: 'Quản lý người dùng')),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickActionCard(icon: Icons.settings_outlined, label: 'Cài đặt', onTap: _handleSettingsTap)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  late Future<_AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _AdminStats.load();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _AdminStats.load();
    });
    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Không tải được analytics: ${snapshot.error}'));
        }

        final stats = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AnalyticsMiniCard(
                        title: 'Tổng doanh thu',
                      value: _formatMoney(stats.totalRevenue),
                      icon: Icons.trending_up_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnalyticsMiniCard(
                        title: 'Doanh thu trung bình',
                      value: stats.totalOrders == 0 ? '0đ' : _formatMoney(stats.totalRevenue / stats.totalOrders),
                      icon: Icons.show_chart_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionHeader(
                title: 'Biểu đồ đơn hàng',
                action: _PillAction(label: 'Tuần này', selected: true),
              ),
              const SizedBox(height: 12),
              _ChartCard(
                height: 210,
                child: _BarChart(values: stats.weeklyOrders),
              ),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Sản phẩm nổi bật', action: _PillAction(label: 'Tuần này', selected: true)),
              const SizedBox(height: 12),
              _TrendingItemsCard(items: stats.recentProducts),
            ],
          ),
        );
      },
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final OrderRepository _orderRepository = OrderRepository.instance;
  late Future<List<OrderInfo>> _ordersFuture;
  String? _currentFilter = 'Preparing';

  final List<_FilterOption> _filters = const [
    _FilterOption('Tất cả', null),
    _FilterOption('Đang chuẩn bị', 'Preparing'),
    _FilterOption('Đang giao', 'Shipping'),
    _FilterOption('Hoàn thành', 'Completed'),
    _FilterOption('Đã hủy', 'Cancelled'),
    _FilterOption('Chưa thanh toán', 'Unpaid'),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = _orderRepository.getAllOrders(statusFilter: _currentFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _currentFilter == filter.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _currentFilter = selected ? filter.value : null;
                        _loadOrders();
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<OrderInfo>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Lỗi: ${snapshot.error}', textAlign: TextAlign.center),
                  ),
                );
              }

              final orders = snapshot.data ?? const [];
              if (orders.isEmpty) {
                return const Center(child: Text('Không có đơn hàng nào'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(_loadOrders);
                  await _ordersFuture;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _OrderCard(order: orders[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<Map<String, Object?>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, Object?>>> _loadUsers() async {
    final db = await AppDatabase.instance;
    return db.query(
      'User',
      columns: ['UserID', 'Role', 'Email', 'FullName', 'IsActive', 'CreatedAt'],
      orderBy: 'UserID DESC',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không tải được người dùng: ${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }

        final users = snapshot.data ?? const [];
        if (users.isEmpty) {
          return const Center(child: Text('Chưa có user nào'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _usersFuture = _loadUsers();
            });
            await _usersFuture;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Row(
                children: [
                  Expanded(
                    child: _AnalyticsMiniCard(
                      title: 'Người dùng hoạt động',
                      value: 'Trực tiếp',
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _AnalyticsMiniCard(
                      title: 'Đăng ký mới',
                      value: 'Hôm nay',
                      icon: Icons.person_add_alt_1_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...users.map((user) => _UserRow(user: user)),
            ],
          ),
        );
      },
    );
  }
}

class _AdminStats {
  _AdminStats({
    required this.totalProducts,
    required this.totalOrders,
    required this.totalCustomers,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.weeklyRevenue,
    required this.weeklyOrders,
    required this.recentProducts,
  });

  final int totalProducts;
  final int totalOrders;
  final int totalCustomers;
  final double totalRevenue;
  final int pendingOrders;
  final List<double> weeklyRevenue;
  final List<double> weeklyOrders;
  final List<_RecentProduct> recentProducts;

  static Future<_AdminStats> load() async {
    final db = await AppDatabase.instance;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final startIso = start.toIso8601String();

    int readCount(List<Map<String, Object?>> rows) {
      if (rows.isEmpty) {
        return 0;
      }
      final first = rows.first.values.first;
      if (first is int) {
        return first;
      }
      if (first is num) {
        return first.toInt();
      }
      return 0;
    }

    final totalProducts = readCount(await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Product'));
    final totalOrders = readCount(await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Invoice'));
    final totalCustomers = readCount(await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Customer'));
    final pendingOrders = readCount(
      await db.rawQuery(
        '''
        SELECT COUNT(*) AS Cnt
        FROM Invoice
        WHERE COALESCE(OrderStatus, PaymentStatus) IN ('Unpaid', 'Preparing')
        ''',
      ),
    );

    final revenueRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(id.UnitPrice * id.Quantity), 0) AS Revenue
      FROM InvoiceDetail id
      JOIN Invoice i ON i.InvoiceID = id.InvoiceID
      WHERE COALESCE(i.OrderStatus, i.PaymentStatus) <> 'Cancelled'
      ''',
    );
    final totalRevenue = (revenueRows.first['Revenue'] as num?)?.toDouble() ?? 0;

    final revenueByDay = await db.rawQuery(
      '''
      SELECT substr(i.CreatedAt, 1, 10) AS DayKey, COALESCE(SUM(id.UnitPrice * id.Quantity), 0) AS Revenue
      FROM Invoice i
      LEFT JOIN InvoiceDetail id ON id.InvoiceID = i.InvoiceID
      WHERE i.CreatedAt >= ?
      GROUP BY DayKey
      ORDER BY DayKey ASC
      ''',
      [startIso],
    );

    final orderByDay = await db.rawQuery(
      '''
      SELECT substr(CreatedAt, 1, 10) AS DayKey, COUNT(*) AS Orders
      FROM Invoice
      WHERE CreatedAt >= ?
      GROUP BY DayKey
      ORDER BY DayKey ASC
      ''',
      [startIso],
    );

    final revenueMap = <String, double>{
      for (final row in revenueByDay) row['DayKey'] as String: (row['Revenue'] as num).toDouble(),
    };
    final orderMap = <String, double>{
      for (final row in orderByDay) row['DayKey'] as String: (row['Orders'] as num).toDouble(),
    };

    final weeklyRevenue = <double>[];
    final weeklyOrders = <double>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(start.year, start.month, start.day + offset);
      final key = day.toIso8601String().split('T').first;
      weeklyRevenue.add(revenueMap[key] ?? 0);
      weeklyOrders.add(orderMap[key] ?? 0);
    }

    final recentProducts = await db.rawQuery(
      '''
      SELECT ProductID, ProductName, StockQuantity, Price
      FROM Product
      ORDER BY ProductID DESC
      LIMIT 5
      ''',
    );

    return _AdminStats(
      totalProducts: totalProducts,
      totalOrders: totalOrders,
      totalCustomers: totalCustomers,
      totalRevenue: totalRevenue,
      pendingOrders: pendingOrders,
      weeklyRevenue: weeklyRevenue,
      weeklyOrders: weeklyOrders,
      recentProducts: recentProducts.map(_RecentProduct.fromRow).toList(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final _AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.pets, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroStat(label: 'Sản phẩm', value: stats.totalProducts.toString(), accent: const Color(0xFFF1D3A8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(label: 'Đơn hàng', value: stats.totalOrders.toString(), accent: const Color(0xFF8FA9F5)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(label: 'Khách hàng', value: stats.totalCustomers.toString(), accent: const Color(0xFFFFD9E2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(label: 'Đang chờ', value: stats.pendingOrders.toString(), accent: const Color(0xFFC8E7C2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.progress,
    this.dark = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final double progress;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF111111) : Colors.white;
    final contentColor = dark ? Colors.white : const Color(0xFF111111);
    final accentColor = dark ? Colors.white24 : const Color(0xFFECECEC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: contentColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: contentColor),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark ? Colors.white70 : AppColors.textLight, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: dark ? Colors.white70 : AppColors.textLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: accentColor,
                valueColor: AlwaysStoppedAnimation<Color>(dark ? Colors.white : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textDark),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.primaryValues, required this.secondaryValues});

  final List<double> primaryValues;
  final List<double> secondaryValues;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(primaryValues: primaryValues, secondaryValues: secondaryValues),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.primaryValues, required this.secondaryValues});

  final List<double> primaryValues;
  final List<double> secondaryValues;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE9E9E9)
      ..strokeWidth = 1;
    final primaryPaint = Paint()
      ..color = const Color(0xFFE1B8C6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final secondaryPaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const lines = 5;
    for (var i = 0; i <= lines; i++) {
      final y = size.height / lines * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = math.max(
      primaryValues.fold<double>(0, math.max),
      secondaryValues.fold<double>(0, math.max),
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final count = math.max(primaryValues.length, secondaryValues.length);

    Path buildPath(List<double> values) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = count <= 1 ? size.width / 2 : size.width / (count - 1) * i;
        final y = size.height - (values[i] / safeMax * (size.height - 18)) - 4;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.cubicTo(x - size.width / (count - 1) / 2, y, x - size.width / (count - 1) / 2, y, x, y);
        }
      }
      return path;
    }

    canvas.drawPath(buildPath(secondaryValues), secondaryPaint);
    canvas.drawPath(buildPath(primaryValues), primaryPaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.primaryValues != primaryValues || oldDelegate.secondaryValues != secondaryValues;
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxValue = values.fold<double>(0, math.max);
        final safeMax = maxValue <= 0 ? 1.0 : maxValue;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(values.length, (index) {
            final height = constraints.maxHeight * (values[index] / safeMax);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: height.clamp(12, constraints.maxHeight - 34),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('D${index + 1}', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _AnalyticsMiniCard extends StatelessWidget {
  const _AnalyticsMiniCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF111111)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingItemsCard extends StatelessWidget {
  const _TrendingItemsCard({required this.items});

  final List<_RecentProduct> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Chưa có sản phẩm để hiển thị'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _TrendingItemRow(item: item),
              if (index != items.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _TrendingItemRow extends StatelessWidget {
  const _TrendingItemRow({required this.item});

  final _RecentProduct item;

  @override
  Widget build(BuildContext context) {
    final isPositive = item.stockQuantity % 2 == 0;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Tồn kho ${item.stockQuantity}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMoney(item.price), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                isPositive ? 'Doanh số +12%' : 'Doanh số -9%',
                style: TextStyle(fontSize: 12, color: isPositive ? Colors.teal : Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF111111)),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

enum _AddItemType { pet, accessory }

class _CategoryChoice {
  const _CategoryChoice({required this.id, required this.name});

  final int id;
  final String name;
}

class _SheetChoiceCard extends StatelessWidget {
  const _SheetChoiceCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF111111)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.label, this.value);

  final String label;
  final String? value;
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderInfo order;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.orderStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Đơn #${order.invoiceId}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(order.statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Khách hàng', style: TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 8),
          ...order.items.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.productName ?? 'Sản phẩm', overflow: TextOverflow.ellipsis)),
                    Text('x${item.quantity}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDate(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              const Spacer(),
              Text(_formatMoney(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final Map<String, Object?> user;

  @override
  Widget build(BuildContext context) {
    final name = ((user['FullName'] as String?) ?? '').trim().isNotEmpty ? (user['FullName'] as String).trim() : 'User';
    final email = (user['Email'] as String?) ?? '';
    final role = ((user['Role'] as String?) ?? 'customer').toLowerCase();
    final isActive = (user['IsActive'] as int?) ?? 0;
    final roleColor = role == 'admin' ? Colors.deepPurple : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF2F2F2),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(role == 'admin' ? 'Quản trị' : 'Khách hàng', style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Text(
                isActive == 1 ? 'Đã xác thực' : 'Chờ xác thực',
                style: TextStyle(fontSize: 12, color: isActive == 1 ? Colors.green : Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentProduct {
  _RecentProduct({required this.productId, required this.productName, required this.stockQuantity, required this.price});

  final int productId;
  final String productName;
  final int stockQuantity;
  final double price;

  factory _RecentProduct.fromRow(Map<String, Object?> row) {
    return _RecentProduct(
      productId: row['ProductID'] as int,
      productName: (row['ProductName'] as String?) ?? '',
      stockQuantity: (row['StockQuantity'] as int?) ?? 0,
      price: (row['Price'] as num?)?.toDouble() ?? 0,
    );
  }
}

String _formatMoney(double value) {
  final whole = value.round();
  final text = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    buffer.write(text[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return '${buffer.toString()}đ';
}

String _formatDate(String value) {
  if (value.isEmpty) {
    return '';
  }
  return value.length >= 10 ? value.substring(0, 10) : value;
}

Color _statusColor(String status) {
  switch (status) {
    case 'Unpaid':
      return Colors.orange;
    case 'Preparing':
      return Colors.blue;
    case 'Shipping':
      return Colors.purple;
    case 'Completed':
      return Colors.green;
    case 'Cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

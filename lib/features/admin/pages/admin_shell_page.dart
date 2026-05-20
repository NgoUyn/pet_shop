import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../../core/widgets/main_wrapper.dart';
import '../../auth/services/auth_repository.dart';
import '../../auth/services/auth_session.dart';
import '../../chat/pages/admin_chat_inbox_page.dart';
import '../../chat/services/chat_repository.dart';
import '../../pet_detail/pages/pet_detail_page.dart';
import '../../product_detail/pages/product_detail_page.dart';
import '../../home/services/product_repository.dart';
import '../../home/services/pet_repository.dart';
import '../../admin/pages/order_management_page.dart';
import '../../admin/pages/admin_warehouse_page.dart';
import '../../admin/pages/user_list_page.dart';
import '../../admin/pages/review_management_page.dart';
import '../../admin/pages/review_statistics_page.dart';
import '../../admin/pages/revenue_statistics_page.dart';
import '../../admin/pages/admin_product_form_page.dart';
import '../../admin/pages/admin_pet_form_page.dart';
import '../../admin/services/promotion_repository.dart';
import '../../notifications/services/notification_repository.dart';
import '../../profile/pages/profile_detail_page.dart';
import '../../profile/services/profile_repository.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  late int _selectedTab;
  late Future<_AdminDashboardSummary> _summaryFuture;
  int _unreadNotifications = 0;
  int _unreadChats = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _summaryFuture = _AdminDashboardSummary.load();
    _refreshBadgeCounts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshBadgeCounts();
      if (mounted) {
        setState(() {
          _summaryFuture = _AdminDashboardSummary.load();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadgeCounts() async {
    try {
      final notifications = await NotificationRepository.instance.unreadCountForCurrentUser();
      final chats = await ChatRepository.instance.unreadCountForCurrentUser();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = notifications;
        _unreadChats = chats;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadNotifications = 0;
        _unreadChats = 0;
      });
    }
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  Future<void> _pushPage(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      _refreshBadgeCounts();
      setState(() {
        _summaryFuture = _AdminDashboardSummary.load();
      });
    }
  }

  Future<void> _openChatInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminChatInboxPage()),
    );
    if (mounted) {
      _refreshBadgeCounts();
      setState(() {
        _summaryFuture = _AdminDashboardSummary.load();
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AdminNotificationCenterPage()),
    );
    if (mounted) {
      _refreshBadgeCounts();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản admin không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthRepository.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
      (route) => false,
    );
  }

  Widget _badgeIcon(IconData icon, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(fontSize: 9, color: Colors.white),
      ),
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminDashboardPage(
        summaryFuture: _summaryFuture,
        unreadChats: _unreadChats,
        unreadNotifications: _unreadNotifications,
        onQuickNavigate: _pushPage,
      ),
      OrderManagementPage(),
      AdminWarehousePage(),
      UserListPage(),
      ReviewManagementPage(),
      _AdminAccountPage(onLogoutTap: _logout),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        title: Text(
          switch (_selectedTab) {
            0 => 'Trang chủ',
            1 => 'Đơn hàng',
            2 => 'Kho hàng',
            3 => 'Khách hàng',
            4 => 'Đánh giá',
            _ => 'Tài khoản',
          },
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _pushPage(const _AdminServicesPage()),
            icon: const Icon(Icons.local_offer_outlined),
            tooltip: 'Dịch vụ',
          ),
          IconButton(
            onPressed: _openNotifications,
            icon: _badgeIcon(Icons.notifications_none_outlined, _unreadNotifications),
            tooltip: 'Thông báo',
          ),
          IconButton(
            onPressed: _openChatInbox,
            icon: _badgeIcon(Icons.chat_bubble_outline, _unreadChats),
            tooltip: 'Tin nhắn',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _selectTab,
        height: 68,
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Kho',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Khách',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: 'Đánh giá',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardPage extends StatelessWidget {
  const _AdminDashboardPage({
    required this.summaryFuture,
    required this.unreadChats,
    required this.unreadNotifications,
    required this.onQuickNavigate,
  });

  final Future<_AdminDashboardSummary> summaryFuture;
  final int unreadChats;
  final int unreadNotifications;
  final Future<void> Function(Widget page) onQuickNavigate;

  String _formatCurrency(num value) {
    final text = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buffer.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminDashboardSummary>(
      future: summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? _AdminDashboardSummary.empty();
        final revenueFuture = _DashboardAnalytics.load();

        return FutureBuilder<_DashboardAnalytics>(
          future: revenueFuture,
          builder: (context, analyticsSnapshot) {
            final analytics = analyticsSnapshot.data ?? _DashboardAnalytics.empty();

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth > 360 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardKpiCard(
                              icon: Icons.receipt_long_outlined,
                              iconColor: const Color(0xFF2F80ED),
                              value: summary.totalOrders.toString(),
                              label: 'Đơn hàng',
                              trend: analytics.orderChangeText,
                              onTap: () => onQuickNavigate(OrderManagementPage()),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardKpiCard(
                              icon: Icons.groups_outlined,
                              iconColor: const Color(0xFF3E7C63),
                              value: summary.totalCustomers.toString(),
                              label: 'Khách hàng',
                              trend: '+0%',
                              onTap: () => onQuickNavigate(UserListPage()),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardKpiCard(
                              icon: Icons.payments_outlined,
                              iconColor: const Color(0xFF5B8DEF),
                              value: _formatCurrency(analytics.monthRevenue),
                              label: 'Doanh thu',
                              trend: analytics.revenueTrendText,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardKpiCard(
                              icon: Icons.warning_amber_outlined,
                              iconColor: const Color(0xFF57A773),
                              value: summary.lowStockCount.toString(),
                              label: 'Cảnh báo tồn kho',
                              trend: summary.lowStockCount == 0 ? '0%' : '+1%',
                              onTap: () => onQuickNavigate(AdminWarehousePage()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Biểu đồ cột doanh thu',
                    child: Column(
                      children: [
                        _RevenueBarChart(items: analytics.revenueBars),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Doanh thu tháng này', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLight)),
                            Text(_formatCurrency(analytics.monthRevenue), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => onQuickNavigate(RevenueStatisticsPage()),
                            icon: const Icon(Icons.trending_up, size: 18),
                            label: const Text('Xem chi tiết thống kê'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Thống kê đánh giá',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => onQuickNavigate(const ReviewStatisticsPage()),
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: const Text('Xem thống kê đánh giá'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Cảnh báo nhanh',
                    child: summary.lowStockItems.isEmpty
                        ? const Text('Không có sản phẩm nào sắp hết hàng.')
                        : Column(
                            children: summary.lowStockItems.take(4).map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8EC),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text('Còn ${item.stock} | ${_formatCurrency(item.price)}', style: const TextStyle(color: AppColors.textLight)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Sản phẩm bán chạy trong tháng',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BestSellerSection(title: 'Thú cưng', items: analytics.topPets),
                        const SizedBox(height: 16),
                        _BestSellerSection(title: 'Phụ kiện', items: analytics.topProducts),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminAccountPage extends StatefulWidget {
  const _AdminAccountPage({required this.onLogoutTap});

  final VoidCallback onLogoutTap;

  @override
  State<_AdminAccountPage> createState() => _AdminAccountPageState();
}

class _AdminAccountPageState extends State<_AdminAccountPage> {
  Future<ProfileData?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reloadProfile();
  }

  void _reloadProfile() {
    final userId = AuthSession.instance.currentUserId.value;
    setState(() {
      _profileFuture = userId == null ? Future.value(null) : ProfileRepository.instance.getProfileByUserId(userId);
    });
  }

  Future<void> _openEditProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileDetailPage()),
    );
    if (changed == true && mounted) {
      _reloadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ')),
      );
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thay đổi mật khẩu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileData?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.fullName.trim().isNotEmpty == true ? profile!.fullName.trim() : 'Quản trị viên';
        final email = profile?.email.trim().isNotEmpty == true ? profile!.email.trim() : 'admin';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFE6F1F0),
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF5A8F93)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Admin', style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(email, style: const TextStyle(color: Color(0xFF477C63), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _AccountActionTile(
                          icon: Icons.person_outline,
                          title: 'Sửa hồ sơ',
                          onTap: _openEditProfile,
                        ),
                        const Divider(height: 1),
                        _AccountActionTile(
                          icon: Icons.lock_outline,
                          title: 'Mật khẩu ứng dụng',
                          onTap: _openChangePassword,
                        ),
                        const Divider(height: 1),
                        _AccountActionTile(
                          icon: Icons.logout,
                          title: 'Đăng xuất',
                          isDestructive: true,
                          onTap: widget.onLogoutTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _AdminInventoryPage extends StatelessWidget {
  const _AdminInventoryPage();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductItem>>(
      future: ProductRepository.instance.listActiveProducts(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ProductItem>[];
        final lowStock = items.where((item) => item.stockQuantity <= 5).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Quản lí kho'),
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Tồn kho thấp',
                child: lowStock.isEmpty
                    ? const Text('Chưa có sản phẩm nào ở mức cảnh báo.')
                    : Column(
                        children: lowStock.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InfoTile(
                              title: item.productName,
                              subtitle: 'Còn ${item.stockQuantity} | ${_money(item.price)}',
                              icon: Icons.inventory_2_outlined,
                              color: Colors.orange,
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Danh sách nhanh',
                child: Column(
                  children: items.take(8).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InfoTile(
                        title: item.productName,
                        subtitle: 'Tồn kho ${item.stockQuantity} | ${_money(item.price)}',
                        icon: Icons.shopping_bag_outlined,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminPromotionsPage extends StatefulWidget {
  const _AdminPromotionsPage();

  @override
  State<_AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends State<_AdminPromotionsPage> {
  late Future<List<PromotionItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = PromotionRepository.instance.listAll();
  }

  void _reload() {
    setState(() {
      _future = PromotionRepository.instance.listAll();
    });
  }

  Future<void> _showAddPromotionDialog() async {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm ưu đãi mới'),
        content: Form(
          key: formKey,
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
                decoration: const InputDecoration(labelText: 'Mô tả (VD: Giảm 20% đơn từ 200k)'),
                maxLines: 2,
                validator: (v) => v?.trim().isEmpty == true ? 'Vui lòng nhập mô tả' : null,
              ),
            ],
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
      ),
    );

    if (added == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPromotionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm ưu đãi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<PromotionItem>>(
        future: _future,
        builder: (context, snapshot) {
          final promotions = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Ưu đãi hiện có',
                child: promotions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('Chưa có ưu đãi nào.', style: TextStyle(color: AppColors.textLight))),
                      )
                    : Column(
                        children: promotions.map((promotion) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InfoTile(
                              title: promotion.code,
                              subtitle: '${promotion.description} • ${promotion.status}',
                              icon: Icons.local_offer_outlined,
                              color: AppColors.secondary,
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 80), // Space for FAB
            ],
          );
        },
      ),
    );
  }
}

class _AdminServicesPage extends StatelessWidget {
  const _AdminServicesPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Quản lí dịch vụ'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ưu đãi', icon: Icon(Icons.local_offer_outlined)),
              Tab(text: 'Điểm', icon: Icon(Icons.stars_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminPromotionsPage(),
            _AdminPointsPage(),
          ],
        ),
      ),
    );
  }
}

class _AdminPointsPage extends StatelessWidget {
  const _AdminPointsPage();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_PointCustomer>>(
      future: _PointCustomer.loadTopCustomers(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const <_PointCustomer>[];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Quy đổi',
                child: const Text('1 điểm = 1.000đ trong cấu hình mặc định.'),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Khách hàng tích điểm cao',
                child: customers.isEmpty
                    ? const Text('Chưa có dữ liệu điểm.')
                    : Column(
                        children: customers.map((customer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InfoTile(
                              title: customer.name,
                              subtitle: '${customer.email} • ${customer.points} điểm',
                              icon: Icons.star_outline,
                              color: AppColors.secondary,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _AdminProductHubPage extends StatelessWidget {
  const _AdminProductHubPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Quản lí sản phẩm'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Thú cưng', icon: Icon(Icons.pets_outlined)),
              Tab(text: 'Phụ kiện', icon: Icon(Icons.shopping_bag_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminPetCatalogPage(),
            _AdminAccessoryCatalogPage(),
          ],
        ),
      ),
    );
  }
}

class _AdminPetCatalogPage extends StatefulWidget {
  const _AdminPetCatalogPage();

  @override
  State<_AdminPetCatalogPage> createState() => _AdminPetCatalogPageState();
}

class _AdminPetCatalogPageState extends State<_AdminPetCatalogPage> {
  late Future<List<PetItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = PetRepository.instance.listActivePets();
    PetRepository.instance.changeToken.addListener(_handlePetsChanged);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_handlePetsChanged);
    super.dispose();
  }

  void _handlePetsChanged() {
    _reload();
  }

  void _reload() {
    setState(() {
      _future = PetRepository.instance.listActivePets();
    });
  }

  Future<bool> _showAddProductForm(BuildContext context) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminPetFormPage()),
    );
    return added == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PetItem>>(
      future: _future,
      builder: (context, snapshot) {
        final pets = snapshot.data ?? const <PetItem>[];

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final added = await _showAddProductForm(context);
              if (added && mounted) {
                _reload();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã thêm thú cưng mới')),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm thú cưng'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Danh sách thú cưng',
                child: pets.isEmpty
                    ? const Text('Chưa có thú cưng nào.')
                    : Column(
                        children: pets.take(12).map((pet) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InfoTile(
                              title: pet.petName,
                              subtitle: '${pet.species} • ${pet.gender ?? 'Chưa rõ'} • ${_money(pet.price ?? 0)}',
                              icon: Icons.pets_outlined,
                              color: AppColors.primary,
                              trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => PetDetailPage(pet: pet, showAdminActions: true)),
                                );
                                if (changed == true && mounted) {
                                  _reload();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminAccessoryCatalogPage extends StatefulWidget {
  const _AdminAccessoryCatalogPage();

  @override
  State<_AdminAccessoryCatalogPage> createState() => _AdminAccessoryCatalogPageState();
}

class _AdminAccessoryCatalogPageState extends State<_AdminAccessoryCatalogPage> {
  late Future<List<ProductItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ProductRepository.instance.listActiveProducts();
    ProductRepository.instance.changeToken.addListener(_handleProductsChanged);
  }

  @override
  void dispose() {
    ProductRepository.instance.changeToken.removeListener(_handleProductsChanged);
    super.dispose();
  }

  void _handleProductsChanged() {
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ProductRepository.instance.listActiveProducts();
    });
  }

  Future<bool> _showAddProductForm(BuildContext context) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProductFormPage()),
    );
    return added == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductItem>>(
      future: _future,
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <ProductItem>[];

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final added = await _showAddProductForm(context);
              if (added && mounted) {
                _reload();
                messenger.showSnackBar(const SnackBar(content: Text('Đã thêm phụ kiện mới')));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm phụ kiện'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Danh sách phụ kiện',
                child: products.isEmpty
                    ? const Text('Chưa có phụ kiện nào.')
                    : Column(
                        children: products.take(12).map((product) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InfoTile(
                              title: product.productName,
                              subtitle: 'Tồn kho ${product.stockQuantity} • ${_money(product.price)}',
                              icon: Icons.shopping_bag_outlined,
                              color: AppColors.secondary,
                              trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailPage(
                                      product: product,
                                      showAdminActions: true,
                                    ),
                                  ),
                                );
                                if (changed == true && mounted) {
                                  _reload();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminNotificationCenterPage extends StatelessWidget {
  const _AdminNotificationCenterPage();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppNotificationItem>>(
      future: NotificationRepository.instance.listForCurrentUser(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotificationItem>[];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Thông báo'),
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: notifications.isEmpty
                ? [const _SectionCard(title: 'Thông báo', child: Text('Chưa có thông báo nào.'))]
                : notifications.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InfoTile(
                        title: item.title,
                        subtitle: item.content,
                        icon: item.isRead ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
                        color: item.isRead ? AppColors.textLight : AppColors.primary,
                        trailing: Text(
                          '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                        onTap: item.isRead
                            ? null
                            : () async {
                                await NotificationRepository.instance.markAsRead(item.notificationId);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                      ),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }
}

class _DashboardAnalytics {
  const _DashboardAnalytics({
    required this.monthRevenue,
    required this.orderChangeText,
    required this.revenueTrendText,
    required this.revenueBars,
    required this.topPets,
    required this.topProducts,
  });

  final double monthRevenue;
  final String orderChangeText;
  final String revenueTrendText;
  final List<_RevenueBarItem> revenueBars;
  final List<_BestSellerItem> topPets;
  final List<_BestSellerItem> topProducts;

  static _DashboardAnalytics empty() {
    return const _DashboardAnalytics(
      monthRevenue: 0,
      orderChangeText: '+0%',
      revenueTrendText: '+0%',
      revenueBars: [],
      topPets: [],
      topProducts: [],
    );
  }

  static Future<_DashboardAnalytics> load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final previousStart = DateTime(now.year, now.month - 1, 1);

    // Lấy tất cả orders từ Firestore
    final snapshot = await FirebaseFirestore.instance.collection('orders').get();
    final allOrders = snapshot.docs.map((doc) => doc.data()).toList();

    // Lọc orders đã thanh toán/hoàn thành
    final paidOrders = allOrders.where((data) {
      final paymentStatus = (data['paymentStatus'] as String? ?? '').toLowerCase();
      final orderStatus = (data['orderStatus'] as String? ?? '').toLowerCase();
      return paymentStatus == 'paid' ||
          paymentStatus == 'completed' ||
          orderStatus == 'completed' ||
          orderStatus == 'shipping';
    }).toList();

    // Tính doanh thu tháng này và tháng trước
    double monthRevenue = 0;
    int monthOrders = 0;
    double previousRevenue = 0;
    int previousOrders = 0;

    for (final data in paidOrders) {
      final createdAt = data['createdAt'] as String? ?? '';
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      if (createdAt.isEmpty) continue;

      DateTime date;
      try {
        date = DateTime.parse(createdAt);
      } catch (_) {
        continue;
      }

      if (date.isAfter(monthStart) && date.isBefore(nextMonth)) {
        monthRevenue += totalAmount;
        monthOrders++;
      } else if (date.isAfter(previousStart) && date.isBefore(monthStart)) {
        previousRevenue += totalAmount;
        previousOrders++;
      }
    }

    // Biểu đồ cột 7 ngày gần đây
    final revenueBars = <_RevenueBarItem>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      double dayRevenue = 0;

      for (final data in paidOrders) {
        final createdAt = data['createdAt'] as String? ?? '';
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        if (createdAt.isEmpty) continue;

        DateTime date;
        try {
          date = DateTime.parse(createdAt);
        } catch (_) {
          continue;
        }

        if (date.isAfter(day) && date.isBefore(nextDay)) {
          dayRevenue += totalAmount;
        }
      }

      revenueBars.add(
        _RevenueBarItem(
          label: '${day.day}',
          value: dayRevenue,
        ),
      );
    }

    // Top bán chạy từ Firestore items
    final Map<String, _BestSellerItem> petSales = {};
    final Map<String, _BestSellerItem> productSales = {};

    for (final data in paidOrders) {
      final createdAt = data['createdAt'] as String? ?? '';
      if (createdAt.isEmpty) continue;

      DateTime date;
      try {
        date = DateTime.parse(createdAt);
      } catch (_) {
        continue;
      }

      if (!date.isAfter(monthStart) || !date.isBefore(nextMonth)) continue;

      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final name = (itemMap['productName'] as String? ?? itemMap['petName'] as String? ?? '').trim();
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
        final revenue = quantity * unitPrice;
        final isPet = itemMap['petId'] != null;

        if (name.isEmpty) continue;

        if (isPet) {
          petSales.update(
            name,
            (existing) => _BestSellerItem(
              name: existing.name,
              soldCount: existing.soldCount + quantity,
              revenue: existing.revenue + revenue,
            ),
            ifAbsent: () => _BestSellerItem(name: name, soldCount: quantity, revenue: revenue),
          );
        } else {
          productSales.update(
            name,
            (existing) => _BestSellerItem(
              name: existing.name,
              soldCount: existing.soldCount + quantity,
              revenue: existing.revenue + revenue,
            ),
            ifAbsent: () => _BestSellerItem(name: name, soldCount: quantity, revenue: revenue),
          );
        }
      }
    }

    // Sắp xếp và lấy top 3
    final topPets = petSales.values.toList()
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final topProducts = productSales.values.toList()
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));

    return _DashboardAnalytics(
      monthRevenue: monthRevenue,
      orderChangeText: _percentText(monthOrders, previousOrders),
      revenueTrendText: _percentText(monthRevenue, previousRevenue),
      revenueBars: revenueBars,
      topPets: topPets.take(3).toList(),
      topProducts: topProducts.take(3).toList(),
    );
  }

  static String _percentText(num current, num previous) {
    if (previous <= 0) {
      return current <= 0 ? '+0%' : '+100%';
    }
    final percent = ((current - previous) / previous * 100).clamp(-999, 999);
    final prefix = percent > 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(0)}%';
  }
}

class _RevenueBarItem {
  const _RevenueBarItem({required this.label, required this.value});

  final String label;
  final double value;
}

class _BestSellerItem {
  const _BestSellerItem({required this.name, required this.soldCount, required this.revenue});

  final String name;
  final int soldCount;
  final double revenue;
}

class _DashboardKpiCard extends StatelessWidget {
  const _DashboardKpiCard({required this.icon, required this.iconColor, required this.value, required this.label, required this.trend, this.onTap});

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(trend, style: TextStyle(color: iconColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
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

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.items});

  final List<_RevenueBarItem> items;

  String _shortMoney(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}tr';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(1, (current, item) => item.value > current ? item.value : current);
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final ratio = (item.value / maxValue).clamp(0.05, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_shortMoney(item.value), style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  const SizedBox(height: 6),
                  Container(
                    height: 120,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 18,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8DC5A2), Color(0xFF2F7A44)]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item.label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BestSellerSection extends StatelessWidget {
  const _BestSellerSection({required this.title, required this.items});

  final String title;
  final List<_BestSellerItem> items;

  String _formatCurrency(double value) {
    final text = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buffer.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        items.isEmpty
            ? const Text('Chưa có dữ liệu bán chạy trong tháng này.')
            : Column(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${item.soldCount} lượt mua • ${_formatCurrency(item.revenue)}', style: const TextStyle(color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({required this.icon, required this.title, required this.onTap, this.isDestructive = false});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFE05252) : const Color(0xFF5A8F93);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isDestructive ? const Color(0xFFB33D3D) : AppColors.textDark)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthRepository.instance.changeCurrentPassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mật khẩu ứng dụng'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu ứng dụng hiện tại',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui lòng nhập mật khẩu ứng dụng hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu ứng dụng mới',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.length < 6) {
                    return 'Mật khẩu ứng dụng mới phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu ứng dụng mới',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu ứng dụng mới';
                  }
                  if (normalized != _newPasswordController.text.trim()) {
                    return 'Mật khẩu ứng dụng xác nhận không khớp';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color ?? AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: AppColors.textLight)),
              ],
            ),
          ),
          trailing != null ? trailing! : const SizedBox.shrink(),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: tile);
  }
}

class _AdminDashboardSummary {
  const _AdminDashboardSummary({
    required this.totalOrders,
    required this.totalCustomers,
    required this.totalPets,
    required this.totalProducts,
    required this.lowStockCount,
    required this.unreadNotifications,
    required this.lowStockItems,
  });

  final int totalOrders;
  final int totalCustomers;
  final int totalPets;
  final int totalProducts;
  final int lowStockCount;
  final int unreadNotifications;
  final List<_LowStockItem> lowStockItems;

  factory _AdminDashboardSummary.empty() {
    return const _AdminDashboardSummary(
      totalOrders: 0,
      totalCustomers: 0,
      totalPets: 0,
      totalProducts: 0,
      lowStockCount: 0,
      unreadNotifications: 0,
      lowStockItems: [],
    );
  }

  static Future<_AdminDashboardSummary> load() async {
    final db = await AppDatabase.instance;

    // Đếm orders từ Firestore
    int totalOrders = 0;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      totalOrders = snapshot.docs.length;
    } catch (_) {
      // Fallback về SQLite nếu Firestore lỗi
      final orders = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Invoice');
      totalOrders = (orders.first['Cnt'] as int?) ?? 0;
    }

    final customers = await db.rawQuery("SELECT COUNT(*) AS Cnt FROM User WHERE lower(Role) = 'customer'");
    final pets = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Pet');
    final products = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Product');
    final lowStockProductRows = await db.rawQuery('''
      SELECT ProductName AS ItemName, StockQuantity, Price
      FROM Product
      WHERE StockQuantity <= 5
      ORDER BY StockQuantity ASC, ProductID DESC
      LIMIT 6
    ''');
    final lowStockPetRows = await db.rawQuery('''
      SELECT PetName AS ItemName, StockQuantity, Price
      FROM Pet
      WHERE StockQuantity > 0 AND StockQuantity <= 5 AND IsActive = 1
      ORDER BY StockQuantity ASC, PetID DESC
      LIMIT 6
    ''');
    final lowStockItems = <_LowStockItem>[
      for (final row in lowStockProductRows)
        _LowStockItem(
          title: (row['ItemName'] as String?) ?? '',
          stock: (row['StockQuantity'] as int?) ?? 0,
          price: (row['Price'] as num?)?.toDouble() ?? 0,
        ),
      for (final row in lowStockPetRows)
        _LowStockItem(
          title: (row['ItemName'] as String?) ?? '',
          stock: (row['StockQuantity'] as int?) ?? 0,
          price: (row['Price'] as num?)?.toDouble() ?? 0,
        ),
    ];
    final unreadNotifications = await NotificationRepository.instance.unreadCountForCurrentUser();

    return _AdminDashboardSummary(
      totalOrders: totalOrders,
      totalCustomers: (customers.first['Cnt'] as int?) ?? 0,
      totalPets: (pets.first['Cnt'] as int?) ?? 0,
      totalProducts: (products.first['Cnt'] as int?) ?? 0,
      lowStockCount: lowStockItems.length,
      unreadNotifications: unreadNotifications,
      lowStockItems: lowStockItems,
    );
  }
}

class _LowStockItem {
  const _LowStockItem({required this.title, required this.stock, required this.price});

  final String title;
  final int stock;
  final double price;
}

class _PointCustomer {
  const _PointCustomer({required this.name, required this.email, required this.points});

  final String name;
  final String email;
  final int points;

  static Future<List<_PointCustomer>> loadTopCustomers() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT u.FullName, u.Email, COALESCE(c.LoyaltyPoints, 0) AS LoyaltyPoints
      FROM User u
      LEFT JOIN Customer c ON c.UserID = u.UserID
      WHERE lower(u.Role) = 'customer'
      ORDER BY COALESCE(c.LoyaltyPoints, 0) DESC, u.UserID DESC
      LIMIT 10
    ''');

    return rows
        .map(
          (row) => _PointCustomer(
            name: (row['FullName'] as String?) ?? '',
            email: (row['Email'] as String?) ?? '',
            points: (row['LoyaltyPoints'] as int?) ?? 0,
          ),
        )
        .toList();
  }
}

String _money(num value) {
  final text = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    buffer.write(text[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
  }
  return '${buffer.toString()}đ';
}

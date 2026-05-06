import 'package:flutter/material.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/favorites/pages/favorites_page.dart';
import '../../features/home/pages/pet_list_page.dart';
import '../../features/home/pages/shop_list_page.dart';
import '../../features/notifications/pages/notification_page.dart';
import '../../features/notifications/services/notification_repository.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/services/auth_session.dart';
import '../constants/app_colors.dart';
import 'app_header.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late int _selectedIndex;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    AuthSession.instance.currentUserId.addListener(_loadNotificationCount);
    _loadNotificationCount();
  }

  @override
  void dispose() {
    AuthSession.instance.currentUserId.removeListener(_loadNotificationCount);
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationRepository.instance.unreadCountForCurrentUser();
    if (!mounted) return;
    setState(() {
      _notificationCount = count;
    });
  }

  final List<Widget> _pages = [
    const HomePage(),
    const FavoritesPage(),
    const PetListPage(),
    const ShopListPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppHeader(
            onSearchText: (q) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tìm: "$q"'))),
            onImageSearch: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text('Chụp ảnh'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chụp ảnh (chưa triển khai)')));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Chọn từ thư viện'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chọn ảnh (chưa triển khai)')));
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
            onNotificationsPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
              if (mounted) {
                await _loadNotificationCount();
              }
            },
            onCartPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mở giỏ hàng (chưa triển khai)'))),
            cartCount: 0,
            notificationCount: _notificationCount,
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 4 && AuthSession.instance.currentUserId.value == null) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Yêu thích',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined),
            activeIcon: Icon(Icons.pets),
            label: 'Mua thú cưng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Cửa hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/favorites/pages/favorites_page.dart';
import '../../features/home/pages/pet_list_page.dart';
import '../../features/home/pages/shop_list_page.dart';
import '../../features/notifications/pages/notification_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../constants/app_colors.dart';
import 'app_header.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const FavoritesPage(),
    const PetListPage(),
    const ShopListPage(),
    const NotificationPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppHeader(
          title: 'Pet Shop',
          onSearchText: (q) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tìm: "${q}"'))),
          onImageSearch: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tìm bằng ảnh (chưa triển khai)'))),
          onCartPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mở giỏ hàng (chưa triển khai)'))),
          cartCount: 0,
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
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
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Thông báo',
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

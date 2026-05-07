import 'package:flutter/material.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/home/pages/pet_list_page.dart';
import '../../features/home/pages/shop_list_page.dart';
import '../../features/notifications/pages/notification_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/favorites/pages/favorites_page.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = [
    const HomePage(),
    const PetListPage(),
    const ShopListPage(),
    const NotificationPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        onFavoritesPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          );
        },
        onNotificationsPressed: () {
          setState(() {
            _selectedIndex = 3;
          });
        },
        onCartPressed: () {
          // Xử lý mở giỏ hàng
        },
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

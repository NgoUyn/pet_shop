import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_wrapper.dart';
import '../../auth/services/auth_repository.dart';
import '../../chat/pages/admin_chat_inbox_page.dart';
import '../../chat/services/chat_repository.dart';
import 'order_management_page.dart';
import 'user_list_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  int _unreadConversations = 0;
  Timer? _refreshTimer;

  final List<Widget> _pages = const [
    OrderManagementPage(),
    UserListPage(),
    AdminChatInboxPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadConversations();
    // Tự động kiểm tra tin nhắn chưa phản hồi mỗi 30 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadConversations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadConversations() async {
    try {
      final conversations = await ChatRepository.instance.watchAdminConversations().first;
      final unreadCount = conversations.where((c) => c.adminUnreadCount > 0).length;
      if (mounted) {
        setState(() {
          _unreadConversations = unreadCount;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
        );
      },
    );

    if (confirmed != true) return;

    await AuthRepository.instance.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị viên'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Người dùng',
          ),
          BottomNavigationBarItem(
            icon: _unreadConversations > 0
                ? Badge(
                    label: Text(
                      _unreadConversations > 99 ? '99+' : _unreadConversations.toString(),
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                    child: const Icon(Icons.chat_bubble_outline),
                  )
                : const Icon(Icons.chat_bubble_outline),
            activeIcon: _unreadConversations > 0
                ? Badge(
                    label: Text(
                      _unreadConversations > 99 ? '99+' : _unreadConversations.toString(),
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                    child: const Icon(Icons.chat_bubble),
                  )
                : const Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

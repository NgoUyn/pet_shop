import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

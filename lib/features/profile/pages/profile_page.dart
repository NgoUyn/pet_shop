import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../chat/pages/chat_page.dart';
import '../../chat/services/chat_repository.dart';
import '../../favorites/pages/favorites_page.dart';
import '../../orders/pages/order_history_page.dart';
import '../services/profile_repository.dart';
import 'profile_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<ProfileData?>? _profileFuture;
  int _unreadChatCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _reloadProfile();
    _loadUnreadCount();
    // Tự động kiểm tra tin nhắn từ shop mỗi 30 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _reloadProfile() {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) {
      setState(() {
        _profileFuture = null;
      });
      return;
    }

    setState(() {
      _profileFuture = ProfileRepository.instance.getProfileByUserId(currentUserId);
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await ChatRepository.instance.unreadCountForCurrentUser();
      if (mounted) {
        setState(() {
          _unreadChatCount = count;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: AuthSession.instance.currentUserId,
      builder: (context, currentUserId, _) {
        if (currentUserId == null) {
          return _buildGuestView(context);
        }

        _profileFuture ??= ProfileRepository.instance.getProfileByUserId(currentUserId);

        return FutureBuilder<ProfileData?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return _buildMissingProfileView(context);
            }

            return Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Container(
                        color: AppColors.primary,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.white,
                              child: Text(
                                profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty ? profile.fullName : 'Người dùng PetShop',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Điểm tích lũy: ${profile.loyaltyPoints}',
                                      style: const TextStyle(color: AppColors.white, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final changed = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(builder: (context) => const ProfileDetailPage()),
                                      );

                                      if (changed == true && mounted) {
                                        _reloadProfile();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.white,
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('Chỉnh sửa hồ sơ'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 15),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Đơn mua', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Xem lịch sử >', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatusItem(Icons.payment, 'Chờ xác nhận', 'Unpaid'),
                                _buildStatusItem(Icons.inventory_2_outlined, 'Chờ lấy hàng', 'Preparing'),
                                _buildStatusItem(Icons.local_shipping_outlined, 'Đang giao', 'Shipping'),
                                _buildStatusItem(Icons.star_outline, 'Đánh giá', 'Completed'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildMenuItem(context, Icons.favorite, 'Danh sách yêu thích', 'Sản phẩm bạn đã thích', destination: const FavoritesPage()),
                      _buildMenuItem(context, Icons.support_agent, 'Liên hệ shop', 'Nhắn tin với hỗ trợ', destination: const ChatPage(), badgeCount: _unreadChatCount)
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 56, color: AppColors.textLight),
                const SizedBox(height: 12),
                const Text(
                  'Bạn chưa đăng nhập',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy đăng nhập để xem và chỉnh sửa thông tin hồ sơ của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingProfileView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tìm thấy thông tin hồ sơ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text('Đăng nhập lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String filter) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderHistoryPage(initialFilter: filter),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle,
      {Widget? destination, int badgeCount = 0}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: badgeCount > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          if (destination != null) {
            // Attempt to mark thread as read on server before navigation so
            // the unread counts are cleared backend-side as well.
            try {
              // Clear all threads for this customer on server-side (covers duplicate docs)
              await ChatRepository.instance.markAllCustomerThreadsAsRead();
            } catch (_) {
              // ignore errors - we'll still clear client badge below
            }

            // Clear badge immediately when user opens chat
            if (_unreadChatCount > 0) {
              setState(() {
                _unreadChatCount = 0;
              });
            }

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
            // Reload unread count when coming back from chat
            _loadUnreadCount();
          }
        },
      ),
    );
  }
}

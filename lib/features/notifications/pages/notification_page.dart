import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../orders/pages/order_history_page.dart';
import '../services/notification_repository.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<AppNotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await NotificationRepository.instance.listForCurrentUser();
      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await NotificationRepository.instance.markAllAsReadForCurrentUser();
    _load();
  }

  Future<void> _onTap(AppNotificationItem item) async {
    // Mark as read
    if (!item.isRead) {
      await NotificationRepository.instance.markAsRead(item.notificationId);
    }

    // Navigate based on type
    if (item.type == 'order' && item.referenceId != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OrderHistoryPage(),
        ),
      );
      if (mounted) _load();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'order':
        return AppColors.primary;
      case 'promotion':
        return Colors.orange;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Đã đọc tất cả'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: AppColors.textLight),
                      SizedBox(height: 12),
                      Text('Chưa có thông báo nào'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _typeColor(item.type).withOpacity(0.15),
                          child: Icon(_typeIcon(item.type), color: _typeColor(item.type)),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(item.createdAt),
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                            if (!item.isRead)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => _onTap(item),
                      );
                    },
                  ),
                ),
    );
  }
}

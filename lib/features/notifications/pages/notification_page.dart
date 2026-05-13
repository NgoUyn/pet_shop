import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../orders/pages/order_history_page.dart';
import '../../reviews/pages/review_page.dart';
import '../services/notification_repository.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<AppNotificationItem> _notifications = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _typeFilter; // null = all, 'order', 'promotion', 'general'
  bool? _readFilter; // null = all, true = read, false = unread

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppNotificationItem> get _filtered {
    var items = _notifications;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)
      ).toList();
    }
    if (_typeFilter != null) {
      items = items.where((n) => n.type == _typeFilter).toList();
    }
    if (_readFilter != null) {
      items = items.where((n) => n.isRead == _readFilter).toList();
    }
    return items;
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
    if (!item.isRead) {
      await NotificationRepository.instance.markAsRead(
        item.notificationId,
        firestoreDocId: item.firestoreDocId,
      );
      // Update local state immediately so UI reflects the change
      setState(() {
        _notifications = _notifications.map((n) {
          if (identical(n, item)) {
            return AppNotificationItem(
              notificationId: n.notificationId,
              userId: n.userId,
              type: n.type,
              title: n.title,
              content: n.content,
              createdAt: n.createdAt,
              isRead: true,
              readAt: DateTime.now(),
              referenceId: n.referenceId,
              referenceType: n.referenceType,
              firestoreDocId: n.firestoreDocId,
            );
          }
          return n;
        }).toList();
      });
    }

    if (item.type == 'order' && item.referenceId != null) {
      if (!mounted) return;
      final isCompleted = item.title.contains('hoàn thành') ||
          item.title.contains('giao thành công');
      final targetPage = isCompleted
          ? ReviewPage(invoiceId: item.referenceId!)
          : const OrderHistoryPage();
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => targetPage),
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

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm thông báo...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Type filter chips
          Row(
            children: [
              _buildChip(
                label: 'Tất cả',
                selected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Thú cưng',
                icon: Icons.pets,
                color: AppColors.primary,
                selected: _typeFilter == 'order',
                onTap: () => setState(() => _typeFilter = _typeFilter == 'order' ? null : 'order'),
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Vật phẩm',
                icon: Icons.shopping_bag,
                color: Colors.orange,
                selected: _typeFilter == 'promotion',
                onTap: () => setState(() => _typeFilter = _typeFilter == 'promotion' ? null : 'promotion'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Read status filter chips
          Row(
            children: [
              _buildChip(
                label: 'Tất cả trạng thái',
                selected: _readFilter == null,
                onTap: () => setState(() => _readFilter = null),
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Chưa đọc',
                selected: _readFilter == false,
                onTap: () => setState(() => _readFilter = _readFilter == false ? null : false),
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Đã đọc',
                selected: _readFilter == true,
                onTap: () => setState(() => _readFilter = _readFilter == true ? null : true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? (color ?? AppColors.primary).withValues(alpha: 0.15) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? (color ?? AppColors.primary) : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? (color ?? AppColors.primary) : AppColors.textLight),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? (color ?? AppColors.primary) : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasActiveFilters = _searchQuery.isNotEmpty || _typeFilter != null || _readFilter != null;
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (hasUnread)
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
              : Column(
                  children: [
                    _buildFilterChips(),
                    const Divider(height: 1),
                    // Filtered list or empty results
                    Expanded(
                      child: filtered.isEmpty && hasActiveFilters
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: AppColors.textLight),
                                  const SizedBox(height: 8),
                                  const Text('Không tìm thấy thông báo nào'),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _typeFilter = null;
                                        _readFilter = null;
                                      });
                                    },
                                    child: const Text('Xoá bộ lọc'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _typeColor(item.type).withValues(alpha: 0.15),
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
                    ),
                  ],
                ),
    );
  }
}

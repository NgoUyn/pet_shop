import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../chat/pages/chat_page.dart';
import '../../orders/services/order_repository.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.userId});

  final int userId;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Map<String, Object?>? _user;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  List<OrderInfo> _recentOrders = [];
  bool _showAllOrders = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetail();
    _loadRecentOrders();
    // Tự động refresh mỗi 30 giây để cập nhật thông tin khách hàng
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUserDetail();
      _loadRecentOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = await AppDatabase.instance;
      final rows = await db.rawQuery('''
        SELECT
          u.UserID,
          u.Role,
          u.Email,
          u.FullName,
          u.IsActive,
          u.VerifiedAt,
          u.CreatedAt,
          u.UpdatedAt,
          u.FirebaseUID,
          c.Phone,
          c.Address,
          COALESCE(c.LoyaltyPoints, 0) AS LoyaltyPoints
        FROM User u
        LEFT JOIN Customer c ON c.UserID = u.UserID
        WHERE u.UserID = ?
        LIMIT 1
      ''', [widget.userId]);

      if (rows.isNotEmpty) {
        setState(() {
          _user = rows.first;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Không tìm thấy người dùng';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final db = await AppDatabase.instance;

      // Get customer ID from this user
      final customerRows = await db.query(
        'Customer',
        columns: ['CustomerID'],
        where: 'UserID = ?',
        whereArgs: [widget.userId],
        limit: 1,
      );

      if (customerRows.isEmpty) return;

      final customerId = customerRows.first['CustomerID'] as int;

      final invoiceRows = await db.rawQuery(
        '''
        SELECT i.*, 
          COALESCE(i.OrderStatus, i.PaymentStatus) as EffectiveStatus
        FROM Invoice i
        WHERE i.CustomerID = ?
        ORDER BY i.CreatedAt DESC
        LIMIT ?
        ''',
        [customerId, _showAllOrders ? 100 : 3],
      );

      final orders = <OrderInfo>[];
      for (final row in invoiceRows) {
        final invoiceId = row['InvoiceID'] as int;

        final detailRows = await db.rawQuery(
          '''
          SELECT id.*, p.ProductName
          FROM InvoiceDetail id
          LEFT JOIN Product p ON id.ProductID = p.ProductID
          WHERE id.InvoiceID = ?
          ''',
          [invoiceId],
        );

        final items = detailRows.map(OrderItemInfo.fromRow).toList();
        orders.add(OrderInfo.fromRow(row, items));
      }

      if (mounted) {
        setState(() {
          _recentOrders = orders;
        });
      }
    } catch (e) {
      print('loadRecentOrders error: $e');
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.deepPurple;
      case 'customer':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chi tiết người dùng #${widget.userId}'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_user != null) ...[
            IconButton(
              onPressed: () => _openChat(context),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat với khách hàng',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final user = _user;
    if (user == null) return;

    final firebaseUid = user['FirebaseUID'] as String?;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Người dùng này chưa có Firebase UID, không thể chat')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(participantUid: firebaseUid),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserDetail,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;
    final role = (user['Role'] as String?) ?? '';
    final isActive = (user['IsActive'] as int?) ?? 0;
    final fullName = (user['FullName'] as String?) ?? '';
    final email = (user['Email'] as String?) ?? '';
    final phone = (user['Phone'] as String?) ?? '';
    final address = (user['Address'] as String?) ?? '';
    final loyaltyPoints = (user['LoyaltyPoints'] as int?) ?? 0;
    final verifiedAt = user['VerifiedAt'] as String?;
    final createdAt = user['CreatedAt'] as String?;
    final updatedAt = user['UpdatedAt'] as String?;
    final firebaseUid = user['FirebaseUID'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + Name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _roleColor(role).withValues(alpha: 0.12),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _roleColor(role),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName.isNotEmpty ? fullName : 'Chưa có tên',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: _roleColor(role),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin chi tiết
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin tài khoản',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Divider(),
                _InfoRow(label: 'User ID', value: '#${user['UserID']}'),
                _InfoRow(label: 'Email', value: email),
                _InfoRow(label: 'Trạng thái', value: isActive == 1 ? 'Đã xác thực' : 'Chờ xác thực',
                    valueColor: isActive == 1 ? Colors.green : Colors.orange),
                _InfoRow(label: 'Firebase UID', value: firebaseUid ?? 'Chưa có'),
                _InfoRow(label: 'Ngày tạo', value: _formatDateTime(createdAt)),
                _InfoRow(label: 'Cập nhật', value: _formatDateTime(updatedAt)),
                _InfoRow(label: 'Xác thực lúc', value: verifiedAt != null ? _formatDateTime(verifiedAt) : 'Chưa xác thực'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin khách hàng (nếu là customer)
          if (role.toLowerCase() == 'customer') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin khách hàng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  _InfoRow(label: 'Số điện thoại', value: phone.isNotEmpty ? phone : 'Chưa có'),
                  _InfoRow(label: 'Địa chỉ', value: address.isNotEmpty ? address : 'Chưa có'),
                  _InfoRow(label: 'Điểm tích lũy', value: '$loyaltyPoints điểm'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lịch sử mua hàng
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử mua hàng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Divider(),
                  if (_recentOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Chưa có đơn hàng nào',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  else ...[
                    ..._recentOrders.take(_showAllOrders ? _recentOrders.length : 3).map((order) => _buildOrderItem(order)),
                    if (_recentOrders.length > 3 && !_showAllOrders)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllOrders = true;
                              });
                              _loadRecentOrders();
                            },
                            icon: const Icon(Icons.expand_more, size: 18),
                            label: Text('Xem tất cả (${_recentOrders.length})'),
                          ),
                        ),
                      ),
                    if (_showAllOrders && _recentOrders.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllOrders = false;
                              });
                              _loadRecentOrders();
                            },
                            icon: const Icon(Icons.expand_less, size: 18),
                            label: const Text('Thu gọn'),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderInfo order) {
    final statusColor = switch (order.orderStatus) {
      'Unpaid' => Colors.orange,
      'Preparing' => Colors.blue,
      'Shipping' => Colors.deepPurple,
      'Completed' => Colors.green,
      'Cancelled' => Colors.red,
      _ => AppColors.textLight,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.invoiceId}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.items.length} sản phẩm - ${order.totalAmount.toStringAsFixed(0)}đ',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(order.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../chat/pages/chat_page.dart';
import '../../orders/services/order_repository.dart';
import '../../reviews/services/review_repository.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.userId, this.initialUser});

  final int userId;
  final Map<String, Object?>? initialUser;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Map<String, Object?>? _user;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  List<OrderInfo> _recentOrders = [];
  bool _isLoadingOrders = true;
  bool _showAllOrders = false;
  List<ReviewItem> _userReviews = [];
  bool _isLoadingReviews = true;
  int _resolvedUserId = 0;

  @override
  void initState() {
    super.initState();
    // Dùng initialUser ngay lập tức nếu có
    if (widget.initialUser != null) {
      _user = Map<String, Object?>.from(widget.initialUser!);
      _loading = false;
    }
    _resolveUserId().then((_) {
      _loadUserDetail().then((_) {
        _loadRecentOrders();
        _loadUserReviews();
      });
    });
    // Tự động refresh mỗi 30 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUserDetail().then((_) {
        _loadRecentOrders();
        _loadUserReviews();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Tìm local UserID từ initialUser hoặc từ email/FirebaseUID
  Future<void> _resolveUserId() async {
    // Nếu widget.userId > 0 thì dùng luôn
    if (widget.userId > 0) {
      _resolvedUserId = widget.userId;
      return;
    }

    final initialUser = widget.initialUser;
    if (initialUser == null) return;

    // Thử lấy UserID từ initialUser (có thể là int hoặc String)
    final userIdRaw = initialUser['UserID'];
    if (userIdRaw is int && userIdRaw > 0) {
      _resolvedUserId = userIdRaw;
      return;
    }
    // Fallback: nếu UserID là string số (vd: "5")
    if (userIdRaw is String) {
      final parsed = int.tryParse(userIdRaw);
      if (parsed != null && parsed > 0) {
        _resolvedUserId = parsed;
        return;
      }
    }

    // Thử tìm theo email
    final email = (initialUser['Email'] as String?)?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      try {
        final db = await AppDatabase.instance;
        final rows = await db.rawQuery(
          'SELECT UserID FROM User WHERE LOWER(TRIM(Email)) = ? LIMIT 1',
          [email],
        );
        if (rows.isNotEmpty) {
          _resolvedUserId = rows.first['UserID'] as int;
          return;
        }
      } catch (_) {}
    }

    // Thử tìm theo FirebaseUID
    final firebaseUid = (initialUser['FirebaseUID'] as String?)?.trim();
    if (firebaseUid != null && firebaseUid.isNotEmpty) {
      try {
        final db = await AppDatabase.instance;
        final rows = await db.rawQuery(
          'SELECT UserID FROM User WHERE FirebaseUID = ? LIMIT 1',
          [firebaseUid],
        );
        if (rows.isNotEmpty) {
          _resolvedUserId = rows.first['UserID'] as int;
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _loadUserDetail() async {
    try {
      // Nếu có initialUser và không có local userId, giữ nguyên initialUser
      if (_resolvedUserId <= 0 && widget.initialUser != null) {
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      if (_resolvedUserId <= 0) {
        setState(() {
          _error = 'Không tìm thấy người dùng';
          _loading = false;
        });
        return;
      }

      final db = await AppDatabase.instance;
      final rows = await db.rawQuery('''
        SELECT
          u.UserID,
          u.Role,
          u.Email,
          u.FullName,
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
      ''', [_resolvedUserId]);

      if (rows.isNotEmpty) {
        final sqliteUser = Map<String, Object?>.from(rows.first);
        // Merge với initialUser: ưu tiên dữ liệu từ Firestore (cross-device source of truth)
        // vì SQLite trên máy admin có thể thiếu hoặc có dữ liệu cũ
        final initial = widget.initialUser;
        if (initial != null) {
          for (final key in ['FirebaseUID', 'FullName', 'Email']) {
            final initialVal = initial[key];
            if (initialVal is String && initialVal.isNotEmpty) {
              sqliteUser[key] = initialVal;
            }
          }
        }
        setState(() {
          _user = sqliteUser;
          _loading = false;
          _error = null;
        });
      } else if (widget.initialUser != null) {
        // Giữ lại initialUser nếu không tìm thấy trong SQLite
        setState(() {
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Không tìm thấy người dùng';
          _loading = false;
        });
      }
    } catch (e) {
      if (widget.initialUser != null) {
        setState(() {
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Lỗi: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final user = _user;
      final firebaseUid = user?['FirebaseUID'] as String?;
      final email = (user?['Email'] as String?)?.trim().toLowerCase();

      final orders = <OrderInfo>[];

      // 1. Load từ local SQLite
      if (_resolvedUserId > 0) {
        try {
          final db = await AppDatabase.instance;
          final invoiceRows = await db.rawQuery('''
            SELECT i.*,
              COALESCE(i.OrderStatus, i.PaymentStatus) as EffectiveStatus,
              u.FullName as CustomerName
            FROM Invoice i
            JOIN Customer c ON i.CustomerID = c.CustomerID
            JOIN User u ON c.UserID = u.UserID
            WHERE c.UserID = ?
            ORDER BY i.CreatedAt DESC
          ''', [_resolvedUserId]);

          for (final row in invoiceRows) {
            final invoiceId = row['InvoiceID'] as int;
            final detailRows = await db.rawQuery('''
              SELECT id.*, p.ProductName, pet.PetName
              FROM InvoiceDetail id
              LEFT JOIN Product p ON id.ProductID = p.ProductID
              LEFT JOIN Pet pet ON id.PetID = pet.PetID
              WHERE id.InvoiceID = ?
            ''', [invoiceId]);

            final items = detailRows.map(OrderItemInfo.fromRow).toList();
            orders.add(OrderInfo.fromRow(row, items));
          }
        } catch (e) {
          print('loadRecentOrders local error: $e');
        }
      }

      // 2. Load từ Firestore để bổ sung
      try {
        List<Map<String, dynamic>> firestoreOrders = [];

        if (firebaseUid != null && firebaseUid.isNotEmpty) {
          try {
            final snapshot = await FirebaseFirestore.instance
                .collection('orders')
                .where('customerFirebaseUid', isEqualTo: firebaseUid)
                .get();
            firestoreOrders = snapshot.docs.map((doc) => doc.data()).toList();
          } catch (_) {}
        }

        if (firestoreOrders.isEmpty && email != null && email.isNotEmpty) {
          try {
            final snapshot = await FirebaseFirestore.instance
                .collection('orders')
                .where('customerEmail', isEqualTo: email)
                .get();
            firestoreOrders = snapshot.docs.map((doc) => doc.data()).toList();
          } catch (_) {}
        }

        final localInvoiceIds = orders.map((o) => o.invoiceId).toSet();
        for (final data in firestoreOrders) {
          final invoiceId = (data['invoiceId'] as num?)?.toInt() ?? 0;
          if (invoiceId == 0 || localInvoiceIds.contains(invoiceId)) continue;

          final itemsData = data['items'] as List<dynamic>? ?? [];
          final items = itemsData.map((item) {
            final itemMap = item as Map<String, dynamic>;
            return OrderItemInfo(
              invoiceDetailId: (itemMap['invoiceDetailId'] as num?)?.toInt() ?? 0,
              productName: (itemMap['productName'] as String? ?? itemMap['petName'] as String? ?? '').trim(),
              quantity: (itemMap['quantity'] as num?)?.toInt() ?? 0,
              unitPrice: (itemMap['unitPrice'] as num?)?.toDouble() ?? 0,
            );
          }).toList();

          final createdAt = data['createdAt'] as String? ?? '';
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          final orderStatus = (data['orderStatus'] as String? ?? data['paymentStatus'] as String? ?? '').toLowerCase();

          orders.add(OrderInfo(
            invoiceId: invoiceId,
            totalAmount: totalAmount,
            createdAt: createdAt,
            orderStatus: orderStatus,
            paymentStatus: orderStatus,
            items: items,
          ));
        }
      } catch (e) {
        print('loadRecentOrders firestore error: $e');
      }

      // Sắp xếp
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      print('loadRecentOrders error: $e');
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _loadUserReviews() async {
    try {
      final user = _user;
      final firebaseUid = user?['FirebaseUID'] as String?;

      final reviews = <ReviewItem>[];

      // 1. Load từ local SQLite
      if (_resolvedUserId > 0) {
        try {
          final db = await AppDatabase.instance;
          final rows = await db.rawQuery('''
            SELECT r.*, u.FullName as CustomerName
            FROM Review r
            LEFT JOIN User u ON r.UserID = u.UserID
            WHERE r.UserID = ?
            ORDER BY r.CreatedAt DESC
          ''', [_resolvedUserId]);

          for (final row in rows) {
            final reviewId = row['ReviewID'] as int;
            final imageRows = await db.query(
              'ReviewImage',
              columns: ['ImageUrl'],
              where: 'ReviewID = ?',
              whereArgs: [reviewId],
              orderBy: 'SortOrder ASC',
            );
            final images = imageRows.map((r) => r['ImageUrl'] as String).toList();
            reviews.add(ReviewItem.fromRow(row, imageUrls: images));
          }
        } catch (e) {
          print('loadUserReviews local error: $e');
        }
      }

      // 2. Load từ Firestore để bổ sung
      try {
        List<ReviewItem> firestoreReviews = [];

        if (firebaseUid != null && firebaseUid.isNotEmpty) {
          try {
            final snapshot = await FirebaseFirestore.instance
                .collection('reviews')
                .where('firebaseUid', isEqualTo: firebaseUid)
                .get();
            firestoreReviews = snapshot.docs
                .map((doc) => ReviewItem.fromFirestore(doc))
                .where((r) => !r.isDeleted)
                .toList();
          } catch (_) {}
        }

        // Merge: tránh trùng lặp
        final localReviewKeys = reviews.map((r) => '${r.invoiceId}_${r.customerName ?? ''}').toSet();
        for (final fr in firestoreReviews) {
          final key = '${fr.invoiceId}_${fr.customerName ?? ''}';
          if (!localReviewKeys.contains(key)) {
            reviews.add(fr);
          }
        }
      } catch (e) {
        print('loadUserReviews firestore error: $e');
      }

      // Sắp xếp
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _userReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('loadUserReviews error: $e');
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Future<void> _promoteToAdmin() async {
    final user = _user;
    if (user == null) return;

    final currentRole = (user['Role'] as String?) ?? '';
    if (currentRole.toLowerCase() == 'admin') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chuyển thành admin'),
          content: Text(
            'Bạn có chắc muốn chuyển ${user['Email'] ?? 'người dùng này'} thành admin không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Chuyển'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final db = await AppDatabase.instance;
      final now = DateTime.now().toIso8601String();
      final firebaseUid = (user['FirebaseUID'] as String?)?.trim();
      final fullName = (user['FullName'] as String?)?.trim() ?? '';
      final email = (user['Email'] as String?)?.trim().toLowerCase() ?? '';

      if (_resolvedUserId > 0) {
        await db.update(
          'User',
          {
            'Role': 'admin',
            'UpdatedAt': now,
          },
          where: 'UserID = ?',
          whereArgs: [_resolvedUserId],
        );
      }

      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        try {
          final userDoc = FirebaseFirestore.instance.collection('users').doc(firebaseUid);
          final existing = await userDoc.get();
          final timestamp = Timestamp.now();

          await userDoc.set(
            {
              'uid': firebaseUid,
              'localUserId': _resolvedUserId > 0 ? _resolvedUserId : null,
              'fullName': fullName,
              'email': email,
              'role': 'admin',
              'updatedAt': timestamp,
              if (!existing.exists) 'createdAt': timestamp,
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          print('promoteToAdmin: error syncing Firestore role: $e');
        }
      }

      if (mounted) {
        setState(() {
          _user = {
            ...user,
            'Role': 'admin',
            'UpdatedAt': now,
          };
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chuyển người dùng thành admin')),
      );
      await _loadUserDetail();
      await _loadRecentOrders();
      await _loadUserReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chuyển thành admin: $e')),
      );
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
        title: Text('Chi tiết người dùng #${widget.initialUser?['UserID']?.toString() ?? widget.userId.toString()}'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (_user != null && (( _user!['Role'] as String?) ?? '').toLowerCase() != 'admin') ...[
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

    final role = (user['Role'] as String?) ?? '';
    if (role.toLowerCase() == 'admin') {
      return;
    }

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
    if (_loading && _user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _user == null) {
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
                onPressed: () {
                  _resolveUserId().then((_) {
                    _loadUserDetail().then((__) {
                      _loadRecentOrders();
                      _loadUserReviews();
                    });
                  });
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;
    final role = (user['Role'] as String?) ?? '';
    final fullName = (user['FullName'] as String?) ?? '';
    final email = (user['Email'] as String?) ?? '';
    final phone = (user['Phone'] as String?) ?? '';
    final address = (user['Address'] as String?) ?? '';
    final loyaltyPoints = (user['LoyaltyPoints'] as int?) ?? 0;
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
                _InfoRow(label: 'Firebase UID', value: firebaseUid ?? 'Chưa có'),
                _InfoRow(label: 'Ngày tạo', value: _formatDateTime(createdAt)),
                _InfoRow(label: 'Cập nhật', value: _formatDateTime(updatedAt)),
                const SizedBox(height: 8),
                if (role.toLowerCase() != 'admin')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _promoteToAdmin,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Chuyển thành admin'),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Người dùng này đã là admin',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin khách hàng (nếu là customer)
          if (role.toLowerCase() != 'admin') ...[
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
                  _InfoRow(label: 'Đơn hàng', value: '${_recentOrders.length} đơn'),
                  _InfoRow(label: 'Đánh giá', value: '${_userReviews.length} đánh giá'),
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
                  if (_isLoadingOrders)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_recentOrders.isEmpty)
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
            const SizedBox(height: 16),

            // Đánh giá của người dùng
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
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Đánh giá',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (!_isLoadingReviews)
                        Text(
                          ' (${_userReviews.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  if (_isLoadingReviews)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_userReviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Người dùng chưa có đánh giá nào',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  else
                    ..._userReviews.map(_buildReviewCard),
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

  Widget _buildReviewCard(ReviewItem review) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: const Color(0xFFFFB300),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '#${review.invoiceId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(review.createdAt.toIso8601String()),
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
          if ((review.content ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.content!,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ],
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: review.imageUrls[i],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
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
  @override
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
            child: SelectableText(
              value,
              maxLines: 3,
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

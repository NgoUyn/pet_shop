import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../chat/pages/admin_chat_inbox_page.dart';
import '../../chat/services/chat_repository.dart';
import 'user_detail_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<Map<String, Object?>>> _usersFuture;
  bool _deletingUser = false;
  int _unreadConversations = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
    _loadUnreadConversations();
    // Tự động refresh danh sách user và tin nhắn chưa phản hồi mỗi 30 giây
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUsers();
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

  Future<List<Map<String, Object?>>> _loadUsers() async {
    final db = await AppDatabase.instance;
    final localUsers = await db.query(
      'User',
      columns: [
        'UserID',
        'Role',
        'Email',
        'FullName',
        'CreatedAt',
        'FirebaseUID',
      ],
      orderBy: 'UserID DESC',
    );

    final firestoreSnapshot = await FirebaseFirestore.instance.collection('users').get();

    final usersByEmail = <String, Map<String, Object?>>{};
    final usersByUid = <String, Map<String, Object?>>{};

    for (final row in localUsers) {
      final email = (row['Email'] as String?)?.trim().toLowerCase();
      final firebaseUid = (row['FirebaseUID'] as String?)?.trim();
      final normalized = Map<String, Object?>.from(row)
        ..putIfAbsent('FirebaseUID', () => firebaseUid)
        ..putIfAbsent('Source', () => 'local');

      if (email != null && email.isNotEmpty) {
        usersByEmail[email] = normalized;
      }
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        usersByUid[firebaseUid] = normalized;
      }
    }

    for (final doc in firestoreSnapshot.docs) {
      final data = doc.data();
      final email = (data['email'] as String?)?.trim().toLowerCase();
      final uid = doc.id;
      final localUserId = data['localUserId'] as int?;
      final createdAt = data['createdAt'];
      final updatedAt = data['updatedAt'];

      final normalized = <String, Object?>{
        'UserID': localUserId ?? uid,
        'Role': (data['role'] as String?) ?? 'customer',
        'Email': (data['email'] as String?) ?? '',
        'FullName': (data['fullName'] as String?) ?? '',
        'CreatedAt': createdAt is Timestamp ? createdAt.toDate().toIso8601String() : (createdAt as String?) ?? '',
        'UpdatedAt': updatedAt is Timestamp ? updatedAt.toDate().toIso8601String() : (updatedAt as String?) ?? null,
        'FirebaseUID': uid,
        'Source': 'firestore',
      };

      if (email != null && email.isNotEmpty) {
        final existing = usersByEmail[email];
        if (existing == null || (existing['FirebaseUID'] as String?)?.isEmpty == true) {
          usersByEmail[email] = normalized;
        }
      } else if (!usersByUid.containsKey(uid)) {
        usersByUid[uid] = normalized;
      }
    }

    final merged = <Map<String, Object?>>[];
    merged.addAll(usersByEmail.values);

    for (final entry in usersByUid.entries) {
      final uid = entry.key;
      final row = entry.value;
      final email = (row['Email'] as String?)?.trim().toLowerCase();
      if (email != null && email.isNotEmpty && usersByEmail.containsKey(email)) {
        continue;
      }
      merged.add(row);
    }

    merged.sort((left, right) {
      final leftCreated = DateTime.tryParse((left['CreatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightCreated = DateTime.tryParse((right['CreatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightCreated.compareTo(leftCreated);
    });

    return merged;
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _usersFuture = _loadUsers();
    });
    await _usersFuture;
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoá user'),
          content: Text('Bạn có chắc muốn xoá user #$userId không? Hành động này không thể hoàn tác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingUser = true;
    });

    try {
      await AppDatabase.deleteUserById(userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá user')),
      );
      await _refreshUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá user thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingUser = false;
        });
      }
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

  int? _resolveLocalUserId(Map<String, Object?> user) {
    final userId = user['UserID'];
    if (userId is int) return userId;
    final localUserId = user['localUserId'];
    if (localUserId is int) return localUserId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách người dùng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          // Chat icon with badge - số nhỏ ở góc
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminChatInboxPage()),
                  );
                  if (mounted) {
                    _loadUnreadConversations();
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Chat',
              ),
              if (_unreadConversations > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _unreadConversations > 99 ? '99+' : _unreadConversations.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _refreshUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh sách user: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshUsers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text('Chưa có user nào'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshUsers,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = users[index];
                final role = (user['Role'] as String?) ?? '';
                final email = (user['Email'] as String?) ?? '';
                final fullName = (user['FullName'] as String?) ?? '';
                final createdAt = user['CreatedAt'] as String?;
                final localUserId = _resolveLocalUserId(user);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailPage(
                          userId: localUserId ?? 0,
                          initialUser: user,
                        ),
                      ),
                    );
                    if (mounted) {
                      await _refreshUsers();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _roleColor(role).withValues(alpha: 0.12),
                              child: Icon(
                                role.toLowerCase() == 'admin' ? Icons.admin_panel_settings : Icons.person,
                                color: _roleColor(role),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName.isNotEmpty ? fullName : 'Không có tên',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email),
                                ],
                              ),
                            ),
                            Text(
                              localUserId != null ? '#$localUserId' : (user['FirebaseUID'] as String?)?.isNotEmpty == true ? 'Firestore' : '-',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(label: role, color: _roleColor(role)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'CreatedAt: ${createdAt ?? '-'}',
                          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _deletingUser || localUserId == null ? null : () => _deleteUser(localUserId),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text(
                              'Xoá',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

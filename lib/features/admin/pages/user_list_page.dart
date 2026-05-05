import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<Map<String, Object?>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, Object?>>> _loadUsers() async {
    final db = await AppDatabase.instance;
    return db.query(
      'User',
      columns: [
        'UserID',
        'Role',
        'Email',
        'FullName',
        'IsActive',
        'VerifiedAt',
        'CreatedAt',
      ],
      orderBy: 'UserID DESC',
    );
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _usersFuture = _loadUsers();
    });
    await _usersFuture;
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

  String _statusLabel(int isActive) => isActive == 1 ? 'Đã xác thực' : 'Chờ xác thực';

  Color _statusColor(int isActive) => isActive == 1 ? Colors.green : Colors.orange;

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
                final isActive = (user['IsActive'] as int?) ?? 0;
                final email = (user['Email'] as String?) ?? '';
                final fullName = (user['FullName'] as String?) ?? '';
                final verifiedAt = user['VerifiedAt'] as String?;
                final createdAt = user['CreatedAt'] as String?;

                return Container(
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
                            '#${user['UserID']}',
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
                          _InfoChip(label: _statusLabel(isActive), color: _statusColor(isActive)),
                          _InfoChip(label: verifiedAt == null ? 'Chưa có VerifiedAt' : 'VerifiedAt có', color: Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CreatedAt: ${createdAt ?? '-'}',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                      ),
                    ],
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
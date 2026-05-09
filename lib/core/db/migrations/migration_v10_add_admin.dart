import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v10: Thêm tài khoản admin mặc định
Future<void> migrateV10AddAdmin(Database db) async {
  debugPrint('Running migrateV10AddAdmin...');
  
  final email = 'pet_shop@gmail.com';

  // Kiểm tra xem admin đã tồn tại chưa
  final existing = await db.query(
    'User',
    where: 'Email = ?',
    whereArgs: [email],
    limit: 1,
  );

  if (existing.isEmpty) {
    final now = DateTime.now().toIso8601String();
    await db.insert('User', {
      'Role': 'admin',
      'Email': email,
      'PasswordHash': 'admin@123',
      'FullName': 'Administrator',
      'IsActive': 1,
      'VerificationToken': null,
      'VerifiedAt': now,
      'CreatedAt': now,
      'UpdatedAt': null,
    });
    debugPrint('migrateV10: Admin user created');
  } else {
    debugPrint('migrateV10: Admin user already exists, skipping');
  }
}

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v16: Ensure admin account exists
Future<void> migrateV16AddAdmin(Database db) async {
  debugPrint('Running migrateV16AddAdmin...');

  final email = 'pet_shop@gmail.com';

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
    debugPrint('migrateV16: Admin user created');
  } else {
    debugPrint('migrateV16: Admin user already exists, skipping');
  }
}

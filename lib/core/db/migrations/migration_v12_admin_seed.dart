import 'package:sqflite/sqflite.dart';

Future<void> migrateV12AdminSeed(Database db) async {
  print('Running migrateV12AdminSeed...');

  const adminEmail = 'huynhmai2755@gmail.com';
  const adminName = 'Admin Shop';
  final now = DateTime.now().toIso8601String();

  final rows = await db.query(
    'User',
    columns: ['UserID', 'Role', 'Email', 'FullName', 'IsActive', 'PasswordHash', 'CreatedAt'],
    where: 'lower(Email) = ?',
    whereArgs: [adminEmail],
    limit: 1,
  );

  if (rows.isNotEmpty) {
    final userId = rows.first['UserID'] as int;
    await db.update(
      'User',
      {
        'Role': 'admin',
        'FullName': adminName,
        'IsActive': 1,
        'UpdatedAt': now,
      },
      where: 'UserID = ?',
      whereArgs: [userId],
    );
    print('migrateV12: admin user already exists, updated baseline fields');
    return;
  }

  await db.insert('User', {
    'Role': 'admin',
    'Email': adminEmail,
    'PasswordHash': 'hash_admin',
    'FullName': adminName,
    'IsActive': 1,
    'VerificationToken': null,
    'VerifiedAt': null,
    'CreatedAt': now,
    'UpdatedAt': null,
    'FirebaseUID': null,
  });

  print('migrateV12: admin seeded');
}
import 'package:sqflite/sqflite.dart';

Future<void> migrateV11FirebaseUid(Database db) async {
  print('Running migrateV11FirebaseUid...');

  final tableInfo = await db.rawQuery("PRAGMA table_info('User');");
  final existingColumns = tableInfo
      .map((row) => (row['name'] as String?) ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();

  if (!existingColumns.contains('FirebaseUID')) {
    await db.execute('ALTER TABLE User ADD COLUMN FirebaseUID TEXT;');
  }

  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_firebase_uid ON User(FirebaseUID) WHERE FirebaseUID IS NOT NULL;',
  );

  print('migrateV11: done');
}
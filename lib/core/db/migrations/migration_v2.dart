import 'package:sqflite/sqflite.dart';

Future<void> migrateV2(Database db) async {
  print('migration_v2: start');
  await db.execute('ALTER TABLE User ADD COLUMN VerificationToken TEXT;');
  await db.execute('ALTER TABLE User ADD COLUMN VerifiedAt TEXT;');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_verification_token ON User(VerificationToken) WHERE VerificationToken IS NOT NULL;'
  );
  print('migration_v2: done');
}

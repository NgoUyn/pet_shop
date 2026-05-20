import 'package:sqflite/sqflite.dart';

Future<void> migrateV21Banner(Database db) async {
  print('Running migrateV21Banner...');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS Banner (
      BannerID INTEGER PRIMARY KEY AUTOINCREMENT,
      Name TEXT,
      ImageURL TEXT NOT NULL,
      IsActive INTEGER NOT NULL DEFAULT 1 CHECK (IsActive IN (0,1)),
      SortOrder INTEGER NOT NULL DEFAULT 0,
      CreatedAt TEXT NOT NULL,
      UpdatedAt TEXT
    );
  ''');

  await db.execute('CREATE INDEX IF NOT EXISTS idx_banner_sort ON Banner(SortOrder);');

  // Seed a sample banner record if none exists
  final rows = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Banner');
  final cnt = (rows.first['Cnt'] as int?) ?? 0;
  if (cnt == 0) {
    final now = DateTime.now().toIso8601String();
    await db.insert('Banner', {
      'Name': 'Default banner',
      'ImageURL': '',
      'IsActive': 1,
      'SortOrder': 0,
      'CreatedAt': now,
      'UpdatedAt': null,
    });
  }
}

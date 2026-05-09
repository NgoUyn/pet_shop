import 'package:sqflite/sqflite.dart';

Future<void> migrateV4(Database db) async {
  print('migration_v4: start');
  final existingTable = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'AppNotification' LIMIT 1;",
  );

  if (existingTable.isEmpty) {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS AppNotification (
        NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        Type TEXT NOT NULL DEFAULT 'general',
        Title TEXT NOT NULL,
        Content TEXT NOT NULL,
        CreatedAt TEXT NOT NULL,
        IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
        ReadAt TEXT,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
      );
      '''
    );
  } else {
    await db.execute('DELETE FROM AppNotification WHERE UserID IS NULL;');

    final tableInfo = await db.rawQuery("PRAGMA table_info('AppNotification');");
    final existingColumns = tableInfo
        .map((e) => (e['name'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();

    final hasTypeColumn = existingColumns.contains('Type');

    await db.execute('ALTER TABLE AppNotification RENAME TO AppNotification_old;');
    await db.execute(
      '''
      CREATE TABLE AppNotification (
        NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        Type TEXT NOT NULL DEFAULT 'general',
        Title TEXT NOT NULL,
        Content TEXT NOT NULL,
        CreatedAt TEXT NOT NULL,
        IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
        ReadAt TEXT,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
      );
      '''
    );

    if (hasTypeColumn) {
      await db.execute(
        '''
        INSERT INTO AppNotification (NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt)
        SELECT NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt
        FROM AppNotification_old;
        '''
      );
    } else {
      await db.execute(
        '''
        INSERT INTO AppNotification (NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt)
        SELECT NotificationID, UserID, 'general', Title, Content, CreatedAt, IsRead, ReadAt
        FROM AppNotification_old;
        '''
      );
    }

    await db.execute('DROP TABLE AppNotification_old;');
  }

  await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_user ON AppNotification(UserID);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_created_at ON AppNotification(CreatedAt);');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_appnotification_user_read_created_at ON AppNotification(UserID, IsRead, CreatedAt);'
  );
  print('migration_v4: done');
}

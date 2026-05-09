import 'package:sqflite/sqflite.dart';

Future<void> migrateV3(Database db) async {
  print('migration_v3: start');
  await db.execute(
    '''
    CREATE TABLE IF NOT EXISTS AppNotification (
      NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
      UserID INTEGER,
      Title TEXT NOT NULL,
      Content TEXT NOT NULL,
      CreatedAt TEXT NOT NULL,
      IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
      ReadAt TEXT,
      FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
    );
    '''
  );

  await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_user ON AppNotification(UserID);');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_created_at ON AppNotification(CreatedAt);');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_appnotification_user_read_created_at ON AppNotification(UserID, IsRead, CreatedAt);'
  );
  print('migration_v3: done');
}

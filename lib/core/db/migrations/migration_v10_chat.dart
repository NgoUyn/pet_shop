import 'package:sqflite/sqflite.dart';

Future<void> migrateV10Chat(Database db) async {
  print('Running migrateV10Chat...');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS ChatMessage (
      ChatMessageID INTEGER PRIMARY KEY AUTOINCREMENT,
      SenderUserID INTEGER NOT NULL,
      ReceiverUserID INTEGER NOT NULL,
      Content TEXT NOT NULL,
      CreatedAt TEXT NOT NULL,
      IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
      ReadAt TEXT,
      FOREIGN KEY (SenderUserID) REFERENCES User(UserID) ON DELETE CASCADE,
      FOREIGN KEY (ReceiverUserID) REFERENCES User(UserID) ON DELETE CASCADE
    );
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_chatmessage_sender_receiver_created_at ON ChatMessage(SenderUserID, ReceiverUserID, CreatedAt);',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_chatmessage_receiver_is_read_created_at ON ChatMessage(ReceiverUserID, IsRead, CreatedAt);',
  );

  print('migrateV10: done');
}

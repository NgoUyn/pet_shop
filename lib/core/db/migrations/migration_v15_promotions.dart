import 'package:sqflite/sqflite.dart';

class MigrationV15Promotions {
  static const int version = 15;

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Promotion (
        PromotionID INTEGER PRIMARY KEY AUTOINCREMENT,
        Code TEXT NOT NULL UNIQUE,
        Description TEXT NOT NULL,
        Status TEXT NOT NULL DEFAULT 'Active',
        CreatedAt TEXT NOT NULL
      )
    ''');
  }
}

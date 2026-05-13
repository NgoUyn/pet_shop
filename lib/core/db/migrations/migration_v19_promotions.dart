import 'package:sqflite/sqflite.dart';

/// Migration v19: Create Promotion table
class MigrationV19Promotions {
  static const int version = 19;

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

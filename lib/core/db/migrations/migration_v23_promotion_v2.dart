import 'package:sqflite/sqflite.dart';

/// Migration v23: Create PromotionV2 table with full discount fields
class MigrationV23PromotionV2 {
  static const int version = 23;

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS PromotionV2 (
        PromotionID INTEGER PRIMARY KEY AUTOINCREMENT,
        Code TEXT NOT NULL UNIQUE,
        Description TEXT NOT NULL,
        DiscountPercent REAL NOT NULL DEFAULT 0,
        MaxDiscount REAL NOT NULL DEFAULT 0,
        MinOrderValue REAL NOT NULL DEFAULT 0,
        ExpiryDate TEXT NOT NULL,
        Status TEXT NOT NULL DEFAULT 'Active',
        CreatedAt TEXT NOT NULL
      )
    ''');
  }
}

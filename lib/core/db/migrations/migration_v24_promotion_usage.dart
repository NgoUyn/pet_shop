import 'package:sqflite/sqflite.dart';

/// Migration v24: Create PromotionUsage table to track per-customer usage
class MigrationV24PromotionUsage {
  static const int version = 24;

  static Future<void> up(Database db) async {
    // Ensure PromotionV2 table exists (in case migration v23 was skipped)
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS PromotionUsage (
        UsageID INTEGER PRIMARY KEY AUTOINCREMENT,
        PromotionID INTEGER NOT NULL,
        CustomerID INTEGER NOT NULL,
        UsedAt TEXT NOT NULL,
        InvoiceID INTEGER NOT NULL,
        FOREIGN KEY (PromotionID) REFERENCES PromotionV2(PromotionID),
        FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
        FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID),
        UNIQUE(PromotionID, CustomerID)
      )
    ''');
  }
}

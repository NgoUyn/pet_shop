import 'package:sqflite/sqflite.dart';

/// Migration v23: Add Status column to Product table
/// Status values: 'Đang bán', 'Hết hàng', 'Ngưng bán'
Future<void> migrateV23ProductStatus(Database db) async {
  // Check if Status column already exists
  final tableInfo = await db.rawQuery("PRAGMA table_info('Product');");
  final existingColumns =
      tableInfo.map((e) => (e['name'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();

  if (!existingColumns.contains('Status')) {
    await db.execute('''
      ALTER TABLE Product ADD COLUMN Status TEXT NOT NULL DEFAULT 'Đang bán'
        CHECK (Status IN ('Đang bán', 'Hết hàng', 'Ngưng bán'));
    ''');

    // Update existing products: if IsActive=0 -> 'Ngưng bán', if StockQuantity<5 -> 'Hết hàng', else 'Đang bán'
    await db.execute('''
      UPDATE Product SET Status = CASE
        WHEN IsActive = 0 THEN 'Ngưng bán'
        WHEN StockQuantity < 5 THEN 'Hết hàng'
        ELSE 'Đang bán'
      END WHERE Status IS NULL OR Status = '';
    ''');
  }
}

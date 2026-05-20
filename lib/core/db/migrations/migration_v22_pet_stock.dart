import 'package:sqflite/sqflite.dart';

Future<void> migrateV22PetStock(Database db) async {
  print('Running migrateV22PetStock...');

  // Add StockQuantity column to Pet
  try {
    await db.execute(
      'ALTER TABLE Pet ADD COLUMN StockQuantity INTEGER NOT NULL DEFAULT 1 CHECK (StockQuantity >= 0)',
    );
    print('migrateV22PetStock: added StockQuantity to Pet');
  } catch (e) {
    print('migrateV22PetStock (maybe already exists): $e');
  }

  // Set default StockQuantity = 1 for all existing rows that have NULL or 0
  await db.rawUpdate(
    'UPDATE Pet SET StockQuantity = 1 WHERE StockQuantity IS NULL OR StockQuantity = 0',
  );

  // Auto-soft-deactivate pets that have 0 stock
  await db.rawUpdate(
    'UPDATE Pet SET IsActive = 0 WHERE StockQuantity <= 0 AND IsActive = 1',
  );

  print('migrateV22PetStock: done');
}

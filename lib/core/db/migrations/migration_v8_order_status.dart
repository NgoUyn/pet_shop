import 'package:sqflite/sqflite.dart';

/// Migration v8: Add OrderStatus column to Invoice table
/// OrderStatus tracks: Unpaid -> Preparing -> Shipping -> Completed / Cancelled
Future<void> migrateV8OrderStatus(Database db) async {
  // Check if OrderStatus column already exists
  final tableInfo = await db.rawQuery("PRAGMA table_info('Invoice');");
  final existingColumns =
      tableInfo.map((e) => (e['name'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();

  if (!existingColumns.contains('OrderStatus')) {
    await db.execute('''
      ALTER TABLE Invoice ADD COLUMN OrderStatus TEXT NOT NULL DEFAULT 'Unpaid'
      CHECK (OrderStatus IN ('Unpaid', 'Preparing', 'Shipping', 'Completed', 'Cancelled'));
    ''');
  }

  // Update existing Paid invoices to have OrderStatus = 'Preparing'
  await db.execute('''
    UPDATE Invoice SET OrderStatus = 'Preparing' WHERE PaymentStatus = 'Paid' AND OrderStatus = 'Unpaid';
  ''');

  // Update existing Processing/Shipping/Completed invoices
  await db.execute('''
    UPDATE Invoice SET OrderStatus = 'Preparing' WHERE PaymentStatus = 'Processing' AND OrderStatus = 'Unpaid';
  ''');
  await db.execute('''
    UPDATE Invoice SET OrderStatus = 'Shipping' WHERE PaymentStatus = 'Shipping' AND OrderStatus = 'Unpaid';
  ''');
  await db.execute('''
    UPDATE Invoice SET OrderStatus = 'Completed' WHERE PaymentStatus = 'Completed' AND OrderStatus = 'Unpaid';
  ''');
  await db.execute('''
    UPDATE Invoice SET OrderStatus = 'Cancelled' WHERE PaymentStatus = 'Cancelled' AND OrderStatus = 'Unpaid';
  ''');
}

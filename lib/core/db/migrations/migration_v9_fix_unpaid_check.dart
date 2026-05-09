import 'package:sqflite/sqflite.dart';

/// Migration v9: Fix the PaymentStatus CHECK constraint to include 'Unpaid'
/// and ensure OrderStatus column exists for databases created with old onCreate schema.
Future<void> migrateV9FixUnpaidCheck(Database db) async {
  print('Running migrateV9FixUnpaidCheck...');

  // Check current Invoice schema
  final tableInfo = await db.rawQuery("PRAGMA table_info('Invoice');");
  final existingColumns =
      tableInfo.map((e) => (e['name'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();

  // Check if OrderStatus column exists, add if not
  if (!existingColumns.contains('OrderStatus')) {
    print('migrateV9: Adding OrderStatus column');
    await db.execute('''
      ALTER TABLE Invoice ADD COLUMN OrderStatus TEXT NOT NULL DEFAULT 'Unpaid'
      CHECK (OrderStatus IN ('Unpaid', 'Preparing', 'Shipping', 'Completed', 'Cancelled'));
    ''');
  }

  // Check if 'Unpaid' is in the PaymentStatus CHECK constraint
  final createSqlRows = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='Invoice' LIMIT 1;",
  );

  if (createSqlRows.isNotEmpty) {
    final sql = (createSqlRows.first['sql'] as String?) ?? '';
    if (sql.contains("'Unpaid'")) {
      print('migrateV9: Invoice already supports Unpaid status, skipping table recreation');
      return;
    }
  }

  print('migrateV9: Recreating Invoice table to add Unpaid to PaymentStatus CHECK');

  // Drop any leftover old table
  await db.execute('DROP TABLE IF EXISTS Invoice_old;');

  // Rename current Invoice to Invoice_old
  await db.execute('ALTER TABLE Invoice RENAME TO Invoice_old;');

  // Create new Invoice with updated CHECK constraint including 'Unpaid' and OrderStatus
  await db.execute('''
    CREATE TABLE Invoice (
      InvoiceID INTEGER PRIMARY KEY AUTOINCREMENT,
      CustomerID INTEGER NOT NULL,
      ShippingAddress TEXT,
      PaymentMethod TEXT,
      PaymentStatus TEXT NOT NULL CHECK (PaymentStatus IN ('Pending', 'Unpaid', 'Paid', 'Cancelled', 'Processing', 'Shipping', 'Completed')),
      TotalAmount REAL NOT NULL DEFAULT 0.0,
      Notes TEXT,
      CreatedAt TEXT NOT NULL,
      UpdatedAt TEXT,
      OrderStatus TEXT NOT NULL DEFAULT 'Unpaid' CHECK (OrderStatus IN ('Unpaid', 'Preparing', 'Shipping', 'Completed', 'Cancelled')),
      FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
    );
  ''');

  // Build column list for data copy
  final oldInfo = await db.rawQuery("PRAGMA table_info('Invoice_old');");
  final oldCols = oldInfo.map((r) => (r['name'] as String?) ?? '').where((s) => s.isNotEmpty).toSet();
  final desired = ['InvoiceID', 'CustomerID', 'ShippingAddress', 'PaymentMethod', 'PaymentStatus', 'TotalAmount', 'Notes', 'CreatedAt', 'UpdatedAt', 'OrderStatus'];
  final common = desired.where((c) => oldCols.contains(c)).toList();

  if (common.isNotEmpty) {
    final cols = common.join(',');
    await db.execute('INSERT INTO Invoice ($cols) SELECT $cols FROM Invoice_old;');
  }

  await db.execute('DROP TABLE IF EXISTS Invoice_old;');
  print('migrateV9: done');
}

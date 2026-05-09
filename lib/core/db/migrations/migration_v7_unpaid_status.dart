import 'package:sqflite/sqflite.dart';

Future<void> migrateV7UnpaidStatus(Database db) async {
  print('Running migrateV7UnpaidStatus...');
  await db.execute('PRAGMA foreign_keys = ON;');

  // Check if Invoice table exists
  final invoiceExistsRows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='Invoice';",
  );
  if (invoiceExistsRows.isEmpty) return;

  // Check if 'Unpaid' is already in the CHECK constraint
  final createSqlRows = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='Invoice' LIMIT 1;",
  );
  if (createSqlRows.isNotEmpty) {
    final sql = (createSqlRows.first['sql'] as String?) ?? '';
    if (sql.contains("'Unpaid'")) {
      print('migration_v7: Invoice already supports Unpaid status, skipping');
      return;
    }
  }

  // Drop any leftover Invoice_old
  try {
    await db.execute('DROP TABLE IF EXISTS Invoice_old;');
  } catch (_) {}

  // Rename current Invoice to Invoice_old
  await db.execute('ALTER TABLE Invoice RENAME TO Invoice_old;');

  // Create new Invoice with updated CHECK constraint including 'Unpaid'
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
      FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
    );
  ''');

  // Copy data from old table
  await db.execute('''
    INSERT INTO Invoice (InvoiceID, CustomerID, ShippingAddress, PaymentMethod, PaymentStatus, TotalAmount, Notes, CreatedAt, UpdatedAt)
    SELECT InvoiceID, CustomerID, ShippingAddress, PaymentMethod, PaymentStatus, TotalAmount, Notes, CreatedAt, UpdatedAt
    FROM Invoice_old;
  ''');

  await db.execute('DROP TABLE IF EXISTS Invoice_old;');
  print('migration_v7: done - added Unpaid status support');
}

import 'package:sqflite/sqflite.dart';

Future<void> migrateV6Payment(Database db) async {
  print('Running migrateV6Payment...');
  await db.execute('PRAGMA foreign_keys = ON;');

  final dbVersion = (await db.rawQuery('PRAGMA user_version;')).first.values.first;
  print('DB user_version=$dbVersion');

  // Create Payment table if missing
  await db.execute(
    '''
    CREATE TABLE IF NOT EXISTS Payment (
      PaymentID INTEGER PRIMARY KEY AUTOINCREMENT,
      InvoiceID INTEGER NOT NULL,
      Amount REAL NOT NULL,
      Method TEXT NOT NULL,
      Status TEXT NOT NULL,
      TransactionCode TEXT,
      PaidAt TEXT,
      FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE
    );
    '''
  );

  // Ensure Invoice has TotalAmount and expanded PaymentStatus values.
  // SQLite doesn't allow altering CHECK easily, so recreate table safely.
  final tableInfo = await db.rawQuery("PRAGMA table_info('Invoice');");
  final existingColumns = tableInfo.map((e) => (e['name'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();

  final hasTotalAmount = existingColumns.contains('TotalAmount');

  if (!hasTotalAmount) {
    // Rename old table
    await db.execute('ALTER TABLE Invoice RENAME TO Invoice_old;');

    // Create new Invoice table
    await db.execute(
      '''
      CREATE TABLE Invoice (
        InvoiceID INTEGER PRIMARY KEY AUTOINCREMENT,
        CustomerID INTEGER NOT NULL,
        ShippingAddress TEXT,
        PaymentMethod TEXT,
        PaymentStatus TEXT NOT NULL CHECK (PaymentStatus IN ('Pending', 'Paid', 'Cancelled', 'Processing', 'Shipping', 'Completed')),
        TotalAmount REAL NOT NULL DEFAULT 0.0,
        Notes TEXT,
        CreatedAt TEXT NOT NULL,
        UpdatedAt TEXT,
        FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
      );
      '''
    );

    // Copy data and compute TotalAmount from InvoiceDetail
    await db.execute(
      '''
      INSERT INTO Invoice (InvoiceID, CustomerID, ShippingAddress, PaymentMethod, PaymentStatus, TotalAmount, Notes, CreatedAt, UpdatedAt)
      SELECT i.InvoiceID, i.CustomerID, i.ShippingAddress, i.PaymentMethod, i.PaymentStatus,
        IFNULL((SELECT SUM(Quantity * UnitPrice) FROM InvoiceDetail WHERE InvoiceID = i.InvoiceID), 0.0) as TotalAmount,
        i.Notes, i.CreatedAt, i.UpdatedAt
      FROM Invoice_old i;
      '''
    );

    await db.execute('DROP TABLE Invoice_old;');
  }

  // Add ProductName and PetName columns to InvoiceDetail if missing
  final detailInfo = await db.rawQuery("PRAGMA table_info('InvoiceDetail');");
  final detailColumns = detailInfo.map((e) => (e['name'] as String?) ?? '').where((e) => e.isNotEmpty).toSet();

  if (!detailColumns.contains('ProductName')) {
    await db.execute('ALTER TABLE InvoiceDetail ADD COLUMN ProductName TEXT;');
  }
  if (!detailColumns.contains('PetName')) {
    await db.execute('ALTER TABLE InvoiceDetail ADD COLUMN PetName TEXT;');
  }

  // Populate names from Product/Pet when possible
  await db.execute(
    '''
    UPDATE InvoiceDetail
    SET ProductName = (
      SELECT ProductName FROM Product WHERE Product.ProductID = InvoiceDetail.ProductID
    )
    WHERE ProductID IS NOT NULL;
    '''
  );

  await db.execute(
    '''
    UPDATE InvoiceDetail
    SET PetName = (
      SELECT PetName FROM Pet WHERE Pet.PetID = InvoiceDetail.PetID
    )
    WHERE PetID IS NOT NULL;
    '''
  );
  print('migration_v6: done');
}

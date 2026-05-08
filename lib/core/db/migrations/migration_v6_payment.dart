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
    // Ensure we have an Invoice table to migrate
    final invoiceExistsRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Invoice';");
    final invoiceExists = invoiceExistsRows.isNotEmpty;

    if (!invoiceExists) {
      // Nothing to migrate
      return;
    }

    // If a previous failed migration left objects referencing Invoice_old (triggers/views), drop them
    try {
      final refs = await db.rawQuery("SELECT name, type, sql FROM sqlite_master WHERE sql LIKE '%Invoice_old%';");
      if (refs.isNotEmpty) {
        for (final r in refs) {
          final name = r['name'] as String?;
          final type = r['type'] as String?;
          if (name == null || type == null) continue;
          try {
            if (type.toLowerCase() == 'trigger') {
              await db.execute('DROP TRIGGER IF EXISTS $name;');
            } else if (type.toLowerCase() == 'view') {
              await db.execute('DROP VIEW IF EXISTS $name;');
            }
            print('migration_v6: dropped $type $name referencing Invoice_old');
          } catch (e) {
            print('migration_v6: failed to drop $type $name : $e');
          }
        }
      }
    } catch (e) {
      print('migration_v6: error scanning sqlite_master for Invoice_old refs: $e');
    }

    // If a previous failed migration left Invoice_old table, drop it first
    final oldExistsRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Invoice_old';");
    final oldExists = oldExistsRows.isNotEmpty;
    if (oldExists) {
      try {
        await db.execute('DROP TABLE IF EXISTS Invoice_old;');
      } catch (_) {}
    }

    // Rename old table
    try {
      await db.execute('ALTER TABLE Invoice RENAME TO Invoice_old;');
    } catch (e) {
      // If rename fails, try to continue safely
      print('migration_v6: rename Invoice failed: $e');
    }

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
    // If InvoiceDetail still references Invoice_old, recreate it to reference new Invoice
    try {
      final fkInfo = await db.rawQuery("PRAGMA foreign_key_list('InvoiceDetail');");
      final refsInvoiceOld = fkInfo.any((r) => (r['table'] as String?) == 'Invoice_old');
      if (refsInvoiceOld) {
        // Rename existing InvoiceDetail to backup
        await db.execute('ALTER TABLE InvoiceDetail RENAME TO InvoiceDetail_old;');

        // Create new InvoiceDetail with FK to Invoice
        await db.execute(
          '''
          CREATE TABLE InvoiceDetail (
            InvoiceDetailID INTEGER PRIMARY KEY AUTOINCREMENT,
            InvoiceID INTEGER NOT NULL,
            ProductID INTEGER,
            PetID INTEGER,
            Quantity INTEGER NOT NULL CHECK (Quantity > 0),
            UnitPrice REAL NOT NULL CHECK (UnitPrice > 0),
            ProductName TEXT,
            PetName TEXT,
            FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE,
            FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
            FOREIGN KEY (PetID) REFERENCES Pet(PetID),
            CHECK (
              (ProductID IS NOT NULL AND PetID IS NULL)
              OR (ProductID IS NULL AND PetID IS NOT NULL)
            )
          );
          '''
        );

        // Copy available columns from old table to new table
        final oldInfo = await db.rawQuery("PRAGMA table_info('InvoiceDetail_old');");
        final oldCols = oldInfo.map((r) => (r['name'] as String?) ?? '').where((s) => s.isNotEmpty).toSet();
        final desired = ['InvoiceDetailID','InvoiceID','ProductID','PetID','Quantity','UnitPrice','ProductName','PetName'];
        final common = desired.where((c) => oldCols.contains(c)).toList();
        if (common.isNotEmpty) {
          final cols = common.join(',');
          await db.execute('INSERT INTO InvoiceDetail ($cols) SELECT $cols FROM InvoiceDetail_old;');
        }

        await db.execute('DROP TABLE IF EXISTS InvoiceDetail_old;');
        print('migration_v6: recreated InvoiceDetail to reference Invoice');
      }
    } catch (e) {
      print('migration_v6: failed to recreate InvoiceDetail: $e');
    }

    // Copy data and compute TotalAmount from InvoiceDetail (only if Invoice_old exists)
    final invoiceOldRows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Invoice_old';");
    if (invoiceOldRows.isNotEmpty) {
      try {
        await db.execute(
          '''
          INSERT INTO Invoice (InvoiceID, CustomerID, ShippingAddress, PaymentMethod, PaymentStatus, TotalAmount, Notes, CreatedAt, UpdatedAt)
          SELECT i.InvoiceID, i.CustomerID, i.ShippingAddress, i.PaymentMethod, i.PaymentStatus,
            IFNULL((SELECT SUM(Quantity * UnitPrice) FROM InvoiceDetail WHERE InvoiceID = i.InvoiceID), 0.0) as TotalAmount,
            i.Notes, i.CreatedAt, i.UpdatedAt
          FROM Invoice_old i;
          ''',
        );

        await db.execute('DROP TABLE IF EXISTS Invoice_old;');
      } catch (e) {
        print('migration_v6: failed to copy/drop Invoice_old: $e');
      }
    }
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

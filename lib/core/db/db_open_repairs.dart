import 'package:sqflite/sqflite.dart';
import 'migrations/migration_v13_favorites_and_notifications.dart';

Future<void> runOpenRepairs(Database db) async {
  await MigrationV13FavoritesAndNotifications.up(db);
  await _repairPetTable(db);
  await _repairReviewTable(db);
  await _dropInvoiceOldReferences(db);
  await _repairInvoiceDetail(db);
  await _repairPayment(db);
}

Future<void> _repairPetTable(Database db) async {
  try {
    final tableInfo = await db.rawQuery("PRAGMA table_info('Pet');");
    final existingColumns = tableInfo
        .map((row) => (row['name'] as String?) ?? '')
        .where((column) => column.isNotEmpty)
        .toSet();

    Future<void> addColumnIfMissing(String columnName, String sql) async {
      if (!existingColumns.contains(columnName)) {
        await db.execute(sql);
      }
    }

    await addColumnIfMissing('Gender', 'ALTER TABLE Pet ADD COLUMN Gender TEXT;');
    await addColumnIfMissing('Age', 'ALTER TABLE Pet ADD COLUMN Age INTEGER;');
    await addColumnIfMissing('Personality', 'ALTER TABLE Pet ADD COLUMN Personality TEXT;');
    await addColumnIfMissing('IsDewormed', 'ALTER TABLE Pet ADD COLUMN IsDewormed INTEGER NOT NULL DEFAULT 0;');
    await addColumnIfMissing('IsVaccinated', 'ALTER TABLE Pet ADD COLUMN IsVaccinated INTEGER NOT NULL DEFAULT 0;');
    await addColumnIfMissing('ImageURL', 'ALTER TABLE Pet ADD COLUMN ImageURL TEXT;');
  } catch (e) {
    print('onOpen: failed to repair Pet table: $e');
  }
}

Future<void> _repairReviewTable(Database db) async {
  try {
    final tableInfo = await db.rawQuery("PRAGMA table_info('Review');");
    final existingColumns = tableInfo
        .map((row) => (row['name'] as String?) ?? '')
        .where((column) => column.isNotEmpty)
        .toSet();

    Future<void> addColumnIfMissing(String columnName, String sql) async {
      if (!existingColumns.contains(columnName)) {
        await db.execute(sql);
      }
    }

    await addColumnIfMissing('FirestoreDocID', 'ALTER TABLE Review ADD COLUMN FirestoreDocID TEXT;');
    await addColumnIfMissing('IsDeleted', 'ALTER TABLE Review ADD COLUMN IsDeleted INTEGER NOT NULL DEFAULT 0;');
    await addColumnIfMissing('IsFlagged', 'ALTER TABLE Review ADD COLUMN IsFlagged INTEGER NOT NULL DEFAULT 0;');
    await addColumnIfMissing('ModerationStatus', 'ALTER TABLE Review ADD COLUMN ModerationStatus TEXT;');
  } catch (e) {
    print('onOpen: failed to repair Review table: $e');
  }
}

Future<void> _dropInvoiceOldReferences(Database db) async {
  try {
    final refs = await db.rawQuery("SELECT name, type, sql FROM sqlite_master WHERE sql LIKE '%Invoice_old%';");
    for (final r in refs) {
      final name = r['name'] as String?;
      final type = r['type'] as String?;
      if (name == null || type == null) continue;
      try {
        if (type.toLowerCase() == 'trigger') {
          await db.execute('DROP TRIGGER IF EXISTS $name;');
          print('onOpen: dropped trigger $name referencing Invoice_old');
        } else if (type.toLowerCase() == 'view') {
          await db.execute('DROP VIEW IF EXISTS $name;');
          print('onOpen: dropped view $name referencing Invoice_old');
        }
      } catch (e) {
        print('onOpen: failed to drop $type $name : $e');
      }
    }
  } catch (e) {
    print('onOpen: error scanning sqlite_master: $e');
  }
}

Future<void> _repairInvoiceDetail(Database db) async {
  try {
    final invDetailRow = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='InvoiceDetail' LIMIT 1;",
    );
    if (invDetailRow.isEmpty) return;

    final sql = (invDetailRow.first['sql'] as String?) ?? '';
    if (!sql.contains('Invoice_old')) return;

    print('onOpen: InvoiceDetail references Invoice_old, recreating InvoiceDetail');
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE InvoiceDetail RENAME TO InvoiceDetail_old;');
      await txn.execute(
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
        ''',
      );

      final oldInfo = await txn.rawQuery("PRAGMA table_info('InvoiceDetail_old');");
      final oldCols = oldInfo
          .map((r) => (r['name'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
      final desired = [
        'InvoiceDetailID',
        'InvoiceID',
        'ProductID',
        'PetID',
        'Quantity',
        'UnitPrice',
        'ProductName',
        'PetName',
      ];
      final common = desired.where((c) => oldCols.contains(c)).toList();
      if (common.isNotEmpty) {
        final cols = common.join(',');
        await txn.execute('INSERT INTO InvoiceDetail ($cols) SELECT $cols FROM InvoiceDetail_old;');
      }

      await txn.execute('DROP TABLE IF EXISTS InvoiceDetail_old;');
    });
    print('onOpen: recreated InvoiceDetail successfully');
  } catch (e) {
    print('onOpen: failed to recreate InvoiceDetail: $e');
  }
}

Future<void> _repairPayment(Database db) async {
  try {
    final paymentRow = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='Payment' LIMIT 1;",
    );
    if (paymentRow.isEmpty) {
      await db.execute(
        '''
        CREATE TABLE Payment (
          PaymentID INTEGER PRIMARY KEY AUTOINCREMENT,
          InvoiceID INTEGER NOT NULL,
          Amount REAL NOT NULL,
          Method TEXT NOT NULL,
          Status TEXT NOT NULL,
          TransactionCode TEXT,
          PaidAt TEXT,
          FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE
        );
        ''',
      );
      return;
    }

    final sql = (paymentRow.first['sql'] as String?) ?? '';
    if (!sql.contains('Invoice_old')) return;

    print('onOpen: Payment references Invoice_old, recreating Payment');
    final paymentOldExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Payment_old' LIMIT 1;",
    );
    if (paymentOldExists.isNotEmpty) {
      await db.execute('DROP TABLE IF EXISTS Payment_old;');
    }

    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE Payment RENAME TO Payment_old;');
      await txn.execute(
        '''
        CREATE TABLE Payment (
          PaymentID INTEGER PRIMARY KEY AUTOINCREMENT,
          InvoiceID INTEGER NOT NULL,
          Amount REAL NOT NULL,
          Method TEXT NOT NULL,
          Status TEXT NOT NULL,
          TransactionCode TEXT,
          PaidAt TEXT,
          FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE
        );
        ''',
      );

      final oldInfo = await txn.rawQuery("PRAGMA table_info('Payment_old');");
      final oldCols = oldInfo
          .map((r) => (r['name'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
      final desired = [
        'PaymentID',
        'InvoiceID',
        'Amount',
        'Method',
        'Status',
        'TransactionCode',
        'PaidAt',
      ];
      final common = desired.where((c) => oldCols.contains(c)).toList();
      if (common.isNotEmpty) {
        final cols = common.join(',');
        await txn.execute('INSERT INTO Payment ($cols) SELECT $cols FROM Payment_old;');
      }

      await txn.execute('DROP TABLE IF EXISTS Payment_old;');
    });
    print('onOpen: recreated Payment successfully');
  } catch (e) {
    print('onOpen: failed to recreate Payment: $e');
  }
}

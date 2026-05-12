import 'package:sqflite/sqflite.dart';
import 'migrations/migration_v6_payment.dart';
import 'migrations/migration_v7_unpaid_status.dart';
import 'migrations/migration_v8_order_status.dart';
import 'migrations/migration_v9_fix_unpaid_check.dart';
import 'migrations/migration_v10_chat.dart';
import 'migrations/migration_v11_firebase_uid.dart';
import 'migrations/migration_v12_admin_seed.dart';
import 'migrations/migration_v13_favorites_and_notifications.dart';
import 'migrations/migration_v14_review.dart';
import 'migrations/migration_v15_promotions.dart';

Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE User ADD COLUMN VerificationToken TEXT;');
    await db.execute('ALTER TABLE User ADD COLUMN VerifiedAt TEXT;');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_user_verification_token ON User(VerificationToken) WHERE VerificationToken IS NOT NULL;');
  }

  if (oldVersion < 3) {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS AppNotification (
        NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER,
        Title TEXT NOT NULL,
        Content TEXT NOT NULL,
        CreatedAt TEXT NOT NULL,
        IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
        ReadAt TEXT,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
      );
      ''',
    );

    await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_user ON AppNotification(UserID);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_created_at ON AppNotification(CreatedAt);');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_appnotification_user_read_created_at ON AppNotification(UserID, IsRead, CreatedAt);',
    );
  }

  if (oldVersion < 4) {
    final existingTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'AppNotification' LIMIT 1;",
    );

    if (existingTable.isEmpty) {
      await db.execute(
        '''
        CREATE TABLE IF NOT EXISTS AppNotification (
          NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
          UserID INTEGER NOT NULL,
          Type TEXT NOT NULL DEFAULT 'general',
          Title TEXT NOT NULL,
          Content TEXT NOT NULL,
          CreatedAt TEXT NOT NULL,
          IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
          ReadAt TEXT,
          FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
        );
        ''',
      );
    } else {
      await db.execute('DELETE FROM AppNotification WHERE UserID IS NULL;');

      final tableInfo = await db.rawQuery("PRAGMA table_info('AppNotification');");
      final existingColumns = tableInfo
          .map((e) => (e['name'] as String?) ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();

      final hasTypeColumn = existingColumns.contains('Type');

      await db.execute('ALTER TABLE AppNotification RENAME TO AppNotification_old;');
      await db.execute(
        '''
        CREATE TABLE AppNotification (
          NotificationID INTEGER PRIMARY KEY AUTOINCREMENT,
          UserID INTEGER NOT NULL,
          Type TEXT NOT NULL DEFAULT 'general',
          Title TEXT NOT NULL,
          Content TEXT NOT NULL,
          CreatedAt TEXT NOT NULL,
          IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
          ReadAt TEXT,
          FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
        );
        ''',
      );

      if (hasTypeColumn) {
        await db.execute(
          '''
          INSERT INTO AppNotification (NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt)
          SELECT NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt
          FROM AppNotification_old;
          ''',
        );
      } else {
        await db.execute(
          '''
          INSERT INTO AppNotification (NotificationID, UserID, Type, Title, Content, CreatedAt, IsRead, ReadAt)
          SELECT NotificationID, UserID, 'general', Title, Content, CreatedAt, IsRead, ReadAt
          FROM AppNotification_old;
          ''',
        );
      }

      await db.execute('DROP TABLE AppNotification_old;');
    }

    await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_user ON AppNotification(UserID);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_appnotification_created_at ON AppNotification(CreatedAt);');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_appnotification_user_read_created_at ON AppNotification(UserID, IsRead, CreatedAt);',
    );
  }

  if (oldVersion < 5) {
    final productCountRows = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Product;');
    final petCountRows = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Pet;');

    final productCount = (productCountRows.first['Cnt'] as int?) ?? 0;
    final petCount = (petCountRows.first['Cnt'] as int?) ?? 0;

    if (productCount == 0) {
      await db.insert(
        'Category',
        {
          'CategoryName': 'Thức ăn thú cưng',
          'Description': 'Các loại thức ăn cho chó mèo',
          'ParentCategoryID': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await db.insert(
        'Category',
        {
          'CategoryName': 'Phụ kiện',
          'Description': 'Phụ kiện cho thú cưng',
          'ParentCategoryID': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final categoryRows = await db.query(
        'Category',
        columns: ['CategoryID', 'CategoryName'],
        where: 'CategoryName IN (?, ?)',
        whereArgs: ['Thức ăn thú cưng', 'Phụ kiện'],
      );

      int? foodCategoryId;
      int? accessoryCategoryId;
      for (final row in categoryRows) {
        final name = row['CategoryName'] as String?;
        final id = row['CategoryID'] as int?;
        if (name == 'Thức ăn thú cưng') foodCategoryId = id;
        if (name == 'Phụ kiện') accessoryCategoryId = id;
      }

      final now = DateTime.now().toIso8601String();

      final products = [
        {
          'CategoryID': foodCategoryId ?? 1,
          'ProductName': 'Hạt cho chó Royal Canin',
          'Price': 250000.0,
          'StockQuantity': 20,
          'Description': 'Thức ăn cao cấp cho chó',
          'ImageURL': '',
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
        {
          'CategoryID': foodCategoryId ?? 1,
          'ProductName': 'Pate cho mèo Whiskas',
          'Price': 35000.0,
          'StockQuantity': 50,
          'Description': 'Pate vị cá ngừ',
          'ImageURL': '',
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
        {
          'CategoryID': accessoryCategoryId ?? 2,
          'ProductName': 'Vòng cổ chó',
          'Price': 80000.0,
          'StockQuantity': 30,
          'Description': 'Vòng cổ da mềm',
          'ImageURL': '',
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
        {
          'CategoryID': accessoryCategoryId ?? 2,
          'ProductName': 'Dây dắt thú cưng',
          'Price': 120000.0,
          'StockQuantity': 25,
          'Description': 'Dây dắt chắc chắn',
          'ImageURL': '',
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
      ];

      for (final product in products) {
        await db.insert('Product', product);
      }
    }

    if (petCount == 0) {
      final customerRows = await db.query(
        'Customer',
        columns: ['CustomerID'],
        limit: 1,
      );
      final customerId = customerRows.isEmpty ? null : customerRows.first['CustomerID'] as int?;
      final now = DateTime.now().toIso8601String();

      final pets = [
        {
          'CustomerID': customerId,
          'PetName': 'Milu',
          'Species': 'Chó Poodle',
          'Description': 'Poodle trắng, 2 tháng tuổi',
          'Price': 3500000.0,
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
        {
          'CustomerID': customerId,
          'PetName': 'Tom',
          'Species': 'Mèo Anh lông ngắn',
          'Description': 'Mèo xám dễ thương',
          'Price': 4200000.0,
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
        {
          'CustomerID': customerId,
          'PetName': 'Max',
          'Species': 'Chó Husky',
          'Description': 'Mắt xanh cực đẹp',
          'Price': 8000000.0,
          'IsActive': 1,
          'CreatedAt': now,
          'UpdatedAt': null,
        },
      ];

      for (final pet in pets) {
        await db.insert('Pet', pet);
      }
    }
  }

  if (oldVersion < 6) {
    await migrateV6Payment(db);
  }

  if (oldVersion < 7) {
    await migrateV7UnpaidStatus(db);
  }

  if (oldVersion < 8) {
    await migrateV8OrderStatus(db);
  }

  if (oldVersion < 9) {
    await migrateV9FixUnpaidCheck(db);
  }

  if (oldVersion < 10) {
    await migrateV10Chat(db);
  }

  if (oldVersion < 11) {
    await migrateV11FirebaseUid(db);
  }

  if (oldVersion < 12) {
    await migrateV12AdminSeed(db);
  }

  if (oldVersion < 13) {
    await MigrationV13FavoritesAndNotifications.up(db);
  }

  if (oldVersion < 14) {
    await MigrationV14Review.up(db);
  }

  if (oldVersion < 15) {
    await MigrationV15Promotions.up(db);
  }
}

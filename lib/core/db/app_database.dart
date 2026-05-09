import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'migrations/migration_v6_payment.dart';
import 'migrations/migration_v7_unpaid_status.dart';
import 'migrations/migration_v8_order_status.dart';
import 'migrations/migration_v9_fix_unpaid_check.dart';
import 'migrations/migration_v10_add_admin.dart';
import 'migrations/migration_v11_pet_details.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pet_shop.db');

    return openDatabase(
      path,
      version: 11,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onOpen: (db) async {
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
        // Detect if InvoiceDetail still references Invoice_old and recreate it
        try {
          final invDetailRow = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='InvoiceDetail' LIMIT 1;");
          if (invDetailRow.isNotEmpty) {
            final sql = (invDetailRow.first['sql'] as String?) ?? '';
            if (sql.contains('Invoice_old')) {
              print('onOpen: InvoiceDetail references Invoice_old, recreating InvoiceDetail');
              await db.transaction((txn) async {
                // rename old
                await txn.execute('ALTER TABLE InvoiceDetail RENAME TO InvoiceDetail_old;');

                // create new InvoiceDetail
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
                  '''
                );

                // copy common columns
                final oldInfo = await txn.rawQuery("PRAGMA table_info('InvoiceDetail_old');");
                final oldCols = oldInfo.map((r) => (r['name'] as String?) ?? '').where((s) => s.isNotEmpty).toSet();
                final desired = ['InvoiceDetailID','InvoiceID','ProductID','PetID','Quantity','UnitPrice','ProductName','PetName'];
                final common = desired.where((c) => oldCols.contains(c)).toList();
                if (common.isNotEmpty) {
                  final cols = common.join(',');
                  await txn.execute('INSERT INTO InvoiceDetail ($cols) SELECT $cols FROM InvoiceDetail_old;');
                }

                await txn.execute('DROP TABLE IF EXISTS InvoiceDetail_old;');
              });
              print('onOpen: recreated InvoiceDetail successfully');
            }
          }
        } catch (e) {
          print('onOpen: failed to recreate InvoiceDetail: $e');
        }

        // Detect if Payment still references Invoice_old and recreate it
        try {
          final paymentRow = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='Payment' LIMIT 1;");
          if (paymentRow.isNotEmpty) {
            final sql = (paymentRow.first['sql'] as String?) ?? '';
            if (sql.contains('Invoice_old')) {
              print('onOpen: Payment references Invoice_old, recreating Payment');
              final paymentOldExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='Payment_old' LIMIT 1;");
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
                  '''
                );

                final oldInfo = await txn.rawQuery("PRAGMA table_info('Payment_old');");
                final oldCols = oldInfo.map((r) => (r['name'] as String?) ?? '').where((s) => s.isNotEmpty).toSet();
                final desired = ['PaymentID', 'InvoiceID', 'Amount', 'Method', 'Status', 'TransactionCode', 'PaidAt'];
                final common = desired.where((c) => oldCols.contains(c)).toList();
                if (common.isNotEmpty) {
                  final cols = common.join(',');
                  await txn.execute('INSERT INTO Payment ($cols) SELECT $cols FROM Payment_old;');
                }

                await txn.execute('DROP TABLE IF EXISTS Payment_old;');
              });
              print('onOpen: recreated Payment successfully');
            }
          }
        } catch (e) {
          print('onOpen: failed to recreate Payment: $e');
        }
      },
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON;');

        final statements = [
          '''
          CREATE TABLE User (
            UserID INTEGER PRIMARY KEY AUTOINCREMENT,
            Role TEXT NOT NULL CHECK (Role IN ('admin', 'customer')),
            Email TEXT NOT NULL UNIQUE,
            PasswordHash TEXT NOT NULL,
            FullName TEXT NOT NULL,
            IsActive INTEGER NOT NULL CHECK (IsActive IN (0, 1)),
            VerificationToken TEXT,
            VerifiedAt TEXT,
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT
          );
          ''',
          '''
          CREATE TABLE Customer (
            CustomerID INTEGER PRIMARY KEY AUTOINCREMENT,
            UserID INTEGER NOT NULL UNIQUE,
            Phone TEXT,
            Address TEXT,
            LoyaltyPoints INTEGER NOT NULL CHECK (LoyaltyPoints >= 0),
            FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
          );
          ''',
          '''
          CREATE TABLE Category (
            CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
            CategoryName TEXT NOT NULL UNIQUE,
            Description TEXT,
            ParentCategoryID INTEGER,
            FOREIGN KEY (ParentCategoryID) REFERENCES Category(CategoryID)
          );
          ''',
          '''
          CREATE TABLE Product (
            ProductID INTEGER PRIMARY KEY AUTOINCREMENT,
            CategoryID INTEGER NOT NULL,
            ProductName TEXT NOT NULL,
            Price REAL NOT NULL CHECK (Price > 0),
            StockQuantity INTEGER NOT NULL CHECK (StockQuantity >= 0),
            Description TEXT,
            ImageURL TEXT,
            IsActive INTEGER NOT NULL CHECK (IsActive IN (0, 1)),
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT,
            FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
          );
          ''',
          '''
          CREATE TABLE Pet (
            PetID INTEGER PRIMARY KEY AUTOINCREMENT,
            CustomerID INTEGER,
            PetName TEXT NOT NULL,
            Species TEXT NOT NULL,
            Description TEXT,
            Price REAL CHECK (Price > 0),
            Age INTEGER,
            Personality TEXT,
            IsDewormed INTEGER NOT NULL DEFAULT 0,
            IsVaccinated INTEGER NOT NULL DEFAULT 0,
            ImageURL TEXT,
            IsActive INTEGER NOT NULL CHECK (IsActive IN (0, 1)),
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT,
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE SET NULL
          );
          ''',
          '''
          CREATE TABLE Cart (
            CartID INTEGER PRIMARY KEY AUTOINCREMENT,
            CustomerID INTEGER NOT NULL UNIQUE,
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT,
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
          );
          ''',
          '''
          CREATE TABLE CartItem (
            CartItemID INTEGER PRIMARY KEY AUTOINCREMENT,
            CartID INTEGER NOT NULL,
            ProductID INTEGER,
            PetID INTEGER,
            Quantity INTEGER NOT NULL CHECK (Quantity > 0),
            UnitPrice REAL NOT NULL CHECK (UnitPrice > 0),
            AddedAt TEXT NOT NULL,
            FOREIGN KEY (CartID) REFERENCES Cart(CartID) ON DELETE CASCADE,
            FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
            FOREIGN KEY (PetID) REFERENCES Pet(PetID),
            CHECK (
              (ProductID IS NOT NULL AND PetID IS NULL)
              OR (ProductID IS NULL AND PetID IS NOT NULL)
            )
          );
          ''',
          '''
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
          ''',
          '''
          CREATE TABLE InvoiceDetail (
            InvoiceDetailID INTEGER PRIMARY KEY AUTOINCREMENT,
            InvoiceID INTEGER NOT NULL,
            ProductID INTEGER,
            PetID INTEGER,
            Quantity INTEGER NOT NULL CHECK (Quantity > 0),
            UnitPrice REAL NOT NULL CHECK (UnitPrice > 0),
            FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE,
            FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
            FOREIGN KEY (PetID) REFERENCES Pet(PetID),
            CHECK (
              (ProductID IS NOT NULL AND PetID IS NULL)
              OR (ProductID IS NULL AND PetID IS NOT NULL)
            )
          );
          ''',
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
          '''
          CREATE INDEX idx_user_email ON User(Email);
          ''',
          '''
          CREATE INDEX idx_user_role ON User(Role);
          ''',
          '''
          CREATE UNIQUE INDEX idx_user_verification_token
          ON User(VerificationToken)
          WHERE VerificationToken IS NOT NULL;
          ''',
          '''
          CREATE INDEX idx_customer_user ON Customer(UserID);
          ''',
          '''
          CREATE INDEX idx_category_parent ON Category(ParentCategoryID);
          ''',
          '''
          CREATE INDEX idx_product_category ON Product(CategoryID);
          ''',
          '''
          CREATE INDEX idx_pet_customer ON Pet(CustomerID);
          ''',
          '''
          CREATE INDEX idx_cart_customer ON Cart(CustomerID);
          ''',
          '''
          CREATE INDEX idx_cartitem_cart ON CartItem(CartID);
          ''',
          '''
          CREATE INDEX idx_invoice_customer ON Invoice(CustomerID);
          ''',
          '''
          CREATE INDEX idx_invoicedetail_invoice ON InvoiceDetail(InvoiceID);
          ''',
          '''
          CREATE UNIQUE INDEX idx_cartitem_cart_product
          ON CartItem(CartID, ProductID)
          WHERE ProductID IS NOT NULL;
          ''',
          '''
          CREATE UNIQUE INDEX idx_cartitem_cart_pet
          ON CartItem(CartID, PetID)
          WHERE PetID IS NOT NULL;
          ''',
          '''
          CREATE INDEX idx_appnotification_user ON AppNotification(UserID);
          ''',
          '''
          CREATE INDEX idx_appnotification_created_at ON AppNotification(CreatedAt);
          ''',
          '''
          CREATE INDEX idx_appnotification_user_read_created_at
          ON AppNotification(UserID, IsRead, CreatedAt);
          ''',
        ];

        for (final sql in statements) {
          await db.execute(sql);
        }

        final now = DateTime.now().toIso8601String();

        // Thêm Admin mặc định
        await db.insert('User', {
          'Role': 'admin',
          'Email': 'pet_shop@gmail.com',
          'PasswordHash': 'admin@123',
          'FullName': 'Administrator',
          'IsActive': 1,
          'VerificationToken': null,
          'VerifiedAt': now,
          'CreatedAt': now,
          'UpdatedAt': null,
        });

        await db.insert('User', {
          'Role': 'customer',
          'Email': 'emgaikwai@gmail.com',
          'PasswordHash': 'hash_customer',
          'FullName': 'Customer Test',
          'IsActive': 1,
          'VerificationToken': null,
          'VerifiedAt': null,
          'CreatedAt': now,
          'UpdatedAt': null,
        });

        // Lấy CustomerID mẫu để gán cho Pet
        await db.insert('Customer', {
          'UserID': 2, // UserID của emgaikwai@gmail.com
          'Phone': '0123456789',
          'Address': 'Ho Chi Minh City',
          'LoyaltyPoints': 100,
        });

        // Tạo Category mẫu
        await db.insert('Category', {
          'CategoryName': 'Thức ăn thú cưng',
          'Description': 'Các loại thức ăn cho chó mèo',
          'ParentCategoryID': null,
        });

        await db.insert('Category', {
          'CategoryName': 'Phụ kiện',
          'Description': 'Phụ kiện cho thú cưng',
          'ParentCategoryID': null,
        });

        // ======================
        // INSERT 10 PRODUCTS
        // ======================

        final products = [
          {
            'CategoryID': 1,
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
            'CategoryID': 1,
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
            'CategoryID': 2,
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
            'CategoryID': 2,
            'ProductName': 'Dây dắt thú cưng',
            'Price': 120000.0,
            'StockQuantity': 25,
            'Description': 'Dây dắt chắc chắn',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 1,
            'ProductName': 'Sữa tắm chó mèo',
            'Price': 95000.0,
            'StockQuantity': 40,
            'Description': 'Sữa tắm khử mùi',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 2,
            'ProductName': 'Khay vệ sinh mèo',
            'Price': 180000.0,
            'StockQuantity': 15,
            'Description': 'Khay vệ sinh chống bắn cát',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 1,
            'ProductName': 'Cát vệ sinh mèo',
            'Price': 70000.0,
            'StockQuantity': 60,
            'Description': 'Cát khử mùi hương lavender',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 2,
            'ProductName': 'Nhà ngủ cho mèo',
            'Price': 320000.0,
            'StockQuantity': 10,
            'Description': 'Nhà ngủ mềm mại',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 2,
            'ProductName': 'Bát ăn inox',
            'Price': 45000.0,
            'StockQuantity': 70,
            'Description': 'Bát ăn chống gỉ',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CategoryID': 1,
            'ProductName': 'Vitamin cho chó mèo',
            'Price': 150000.0,
            'StockQuantity': 18,
            'Description': 'Vitamin tăng sức đề kháng',
            'ImageURL': '',
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
        ];

        for (final product in products) {
          await db.insert('Product', product);
        }

        // ======================
        // INSERT 10 PETS
        // ======================

        final pets = [
          {
            'CustomerID': 1,
            'PetName': 'Milu',
            'Species': 'Chó Poodle',
            'Description': 'Poodle trắng, 2 tháng tuổi',
            'Price': 3500000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Tom',
            'Species': 'Mèo Anh lông ngắn',
            'Description': 'Mèo xám dễ thương',
            'Price': 4200000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Bibi',
            'Species': 'Chó Corgi',
            'Description': 'Corgi chân ngắn',
            'Price': 7000000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Luna',
            'Species': 'Mèo Ba Tư',
            'Description': 'Lông dài trắng',
            'Price': 5500000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Max',
            'Species': 'Chó Husky',
            'Description': 'Mắt xanh cực đẹp',
            'Price': 8000000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Nabi',
            'Species': 'Mèo Scottish',
            'Description': 'Tai cụp đáng yêu',
            'Price': 6000000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Coco',
            'Species': 'Chó Chihuahua',
            'Description': 'Nhỏ nhắn lanh lợi',
            'Price': 2800000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Mimi',
            'Species': 'Mèo Munchkin',
            'Description': 'Chân ngắn siêu cute',
            'Price': 7500000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Rocky',
            'Species': 'Chó Golden',
            'Description': 'Hiền lành thân thiện',
            'Price': 6500000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
          {
            'CustomerID': 1,
            'PetName': 'Snow',
            'Species': 'Mèo Ragdoll',
            'Description': 'Lông trắng xanh mắt',
            'Price': 9000000.0,
            'IsActive': 1,
            'CreatedAt': now,
            'UpdatedAt': null,
          },
        ];

        for (final pet in pets) {
          await db.insert('Pet', pet);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('PRAGMA foreign_keys = ON;');

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
            // Drop any old "broadcast" notifications to satisfy the new NOT NULL constraint.
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
          // Seed some sample catalog/pets for existing databases that were created
          // before we added the initial data in onCreate(). Only seed when empty.
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
          // Run migration to add Payment table and Invoice.TotalAmount
          await migrateV6Payment(db);
        }

        if (oldVersion < 7) {
          // Run migration to add 'Unpaid' status to Invoice
          await migrateV7UnpaidStatus(db);
        }

        if (oldVersion < 8) {
          // Run migration to add OrderStatus column
          await migrateV8OrderStatus(db);
        }

        if (oldVersion < 9) {
          // Run migration to fix PaymentStatus CHECK constraint and ensure OrderStatus column
          await migrateV9FixUnpaidCheck(db);
        }

        if (oldVersion < 10) {
          // Migration v10: Thêm tài khoản admin mặc định
          await migrateV10AddAdmin(db);
        }

        if (oldVersion < 11) {
          // Migration v11: Bổ sung thông tin chi tiết cho Pet
          await migrateV11PetDetails(db);
        }
      },
    );
  }

  static Future<void> deleteUserById(int userId) async {
    final db = await instance;

    await db.transaction((txn) async {
      final userRows = await txn.query(
        'User',
        columns: ['Role'],
        where: 'UserID = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (userRows.isEmpty) {
        throw StateError('Không tìm thấy user để xoá');
      }

      final customerRows = await txn.query(
        'Customer',
        columns: ['CustomerID'],
        where: 'UserID = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (customerRows.isNotEmpty) {
        final customerId = customerRows.first['CustomerID'] as int;

        await txn.delete(
          'CartItem',
          where: 'CartID IN (SELECT CartID FROM Cart WHERE CustomerID = ?)',
          whereArgs: [customerId],
        );

        await txn.delete(
          'Cart',
          where: 'CustomerID = ?',
          whereArgs: [customerId],
        );

        await txn.delete(
          'InvoiceDetail',
          where: 'InvoiceID IN (SELECT InvoiceID FROM Invoice WHERE CustomerID = ?)',
          whereArgs: [customerId],
        );

        await txn.delete(
          'Invoice',
          where: 'CustomerID = ?',
          whereArgs: [customerId],
        );

        await txn.update(
          'Pet',
          {'CustomerID': null},
          where: 'CustomerID = ?',
          whereArgs: [customerId],
        );

        await txn.delete(
          'Customer',
          where: 'CustomerID = ?',
          whereArgs: [customerId],
        );
      }

      await txn.delete(
        'User',
        where: 'UserID = ?',
        whereArgs: [userId],
      );
    });
  }
}

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 2,
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
            PaymentStatus TEXT NOT NULL CHECK (PaymentStatus IN ('Pending', 'Paid', 'Cancelled')),
            Notes TEXT,
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT,
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
        ];

        for (final sql in statements) {
          await db.execute(sql);
        }

        await db.insert('User', {
          'Role': 'customer',
          'Email': 'emgaikwai@gmail.com',
          'PasswordHash': 'hash_customer',
          'FullName': 'Customer Test',
          'IsActive': 1,
          'VerificationToken': null,
          'VerifiedAt': null,
          'CreatedAt': DateTime.now().toIso8601String(),
          'UpdatedAt': null,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('PRAGMA foreign_keys = ON;');

        if (oldVersion < 2) {
          await db.execute('ALTER TABLE User ADD COLUMN VerificationToken TEXT;');
          await db.execute('ALTER TABLE User ADD COLUMN VerifiedAt TEXT;');
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_user_verification_token ON User(VerificationToken) WHERE VerificationToken IS NOT NULL;');
        }
      },
    );
  }
}
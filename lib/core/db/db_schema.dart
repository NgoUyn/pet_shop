import 'package:sqflite/sqflite.dart';

Future<void> createBaseSchema(Database db) async {
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
      UpdatedAt TEXT,
      FirebaseUID TEXT
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
    '''
    CREATE TABLE Review (
      ReviewID INTEGER PRIMARY KEY AUTOINCREMENT,
      InvoiceID INTEGER NOT NULL,
      UserID INTEGER NOT NULL,
      Rating INTEGER NOT NULL CHECK (Rating >= 1 AND Rating <= 5),
      Content TEXT,
      CreatedAt TEXT NOT NULL,
      UpdatedAt TEXT,
      FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID) ON DELETE CASCADE,
      FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE,
      UNIQUE(InvoiceID, UserID)
    );
    ''',
    '''
    CREATE INDEX idx_review_invoice ON Review(InvoiceID);
    ''',
    '''
    CREATE INDEX idx_review_user ON Review(UserID);
    ''',
    '''
    CREATE TABLE ReviewImage (
      ReviewImageID INTEGER PRIMARY KEY AUTOINCREMENT,
      ReviewID INTEGER NOT NULL,
      ImageUrl TEXT NOT NULL,
      SortOrder INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (ReviewID) REFERENCES Review(ReviewID) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE INDEX idx_reviewimage_review ON ReviewImage(ReviewID);
    ''',
    '''
    CREATE TABLE ChatMessage (
      ChatMessageID INTEGER PRIMARY KEY AUTOINCREMENT,
      SenderUserID INTEGER NOT NULL,
      ReceiverUserID INTEGER NOT NULL,
      Content TEXT NOT NULL,
      CreatedAt TEXT NOT NULL,
      IsRead INTEGER NOT NULL DEFAULT 0 CHECK (IsRead IN (0, 1)),
      ReadAt TEXT,
      FOREIGN KEY (SenderUserID) REFERENCES User(UserID) ON DELETE CASCADE,
      FOREIGN KEY (ReceiverUserID) REFERENCES User(UserID) ON DELETE CASCADE
    );
    ''',
    '''
    CREATE INDEX idx_chatmessage_sender_receiver_created_at
    ON ChatMessage(SenderUserID, ReceiverUserID, CreatedAt);
    ''',
    '''
    CREATE INDEX idx_chatmessage_receiver_is_read_created_at
    ON ChatMessage(ReceiverUserID, IsRead, CreatedAt);
    ''',
  ];

  for (final sql in statements) {
    await db.execute(sql);
  }
}

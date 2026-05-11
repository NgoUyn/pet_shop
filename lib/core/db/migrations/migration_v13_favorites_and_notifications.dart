import 'package:sqflite/sqflite.dart';

class MigrationV13FavoritesAndNotifications {
  static const int version = 13;

  static Future<void> up(Database db) async {
    // Create FavoriteProduct table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS FavoriteProduct (
        FavoriteID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        ProductID INTEGER NOT NULL,
        CreatedAt TEXT NOT NULL,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE,
        FOREIGN KEY (ProductID) REFERENCES Product(ProductID) ON DELETE CASCADE,
        UNIQUE(UserID, ProductID)
      )
    ''');

    // Create FavoritePet table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS FavoritePet (
        FavoriteID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        PetID INTEGER NOT NULL,
        CreatedAt TEXT NOT NULL,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE,
        FOREIGN KEY (PetID) REFERENCES Pet(PetID) ON DELETE CASCADE,
        UNIQUE(UserID, PetID)
      )
    ''');

    // Add ReferenceID column to AppNotification for linking to orders
    final tableInfo = await db.rawQuery("PRAGMA table_info('AppNotification')");
    final existingColumns = tableInfo.map((r) => r['name'] as String).toList();

    if (!existingColumns.contains('ReferenceID')) {
      await db.execute('ALTER TABLE AppNotification ADD COLUMN ReferenceID INTEGER');
    }
    if (!existingColumns.contains('ReferenceType')) {
      await db.execute("ALTER TABLE AppNotification ADD COLUMN ReferenceType TEXT DEFAULT 'order'");
    }

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favproduct_user ON FavoriteProduct(UserID)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favpet_user ON FavoritePet(UserID)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notification_reference ON AppNotification(ReferenceID, ReferenceType)');
  }
}

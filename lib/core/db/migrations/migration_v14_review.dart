import 'package:sqflite/sqflite.dart';

class MigrationV14Review {
  static const int version = 14;

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Review (
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
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_review_invoice ON Review(InvoiceID)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_review_user ON Review(UserID)');
  }
}

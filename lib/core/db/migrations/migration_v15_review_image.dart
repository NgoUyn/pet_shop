import 'package:sqflite/sqflite.dart';

class MigrationV15ReviewImage {
  static const int version = 15;

  static Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ReviewImage (
        ReviewImageID INTEGER PRIMARY KEY AUTOINCREMENT,
        ReviewID INTEGER NOT NULL,
        ImageUrl TEXT NOT NULL,
        SortOrder INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ReviewID) REFERENCES Review(ReviewID) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_reviewimage_review ON ReviewImage(ReviewID)');
  }
}

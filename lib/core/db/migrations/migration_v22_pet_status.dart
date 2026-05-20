import 'package:sqflite/sqflite.dart';

class MigrationV22PetStatus {
  static Future<void> up(Database db) async {
    // Add Status column to Pet table
    await db.execute('''
      ALTER TABLE Pet ADD COLUMN Status TEXT NOT NULL DEFAULT 'đang bán'
        CHECK (Status IN ('đang bán', 'đã bán', 'ngưng bán'))
    ''');
  }
}

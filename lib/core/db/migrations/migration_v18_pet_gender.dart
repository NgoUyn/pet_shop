import 'package:sqflite/sqflite.dart';

/// Migration v18: Add Gender column to Pet table
Future<void> migrateV18PetGender(Database db) async {
  final tableInfo = await db.rawQuery("PRAGMA table_info('Pet');");
  final existingColumns = tableInfo
      .map((row) => (row['name'] as String?) ?? '')
      .where((column) => column.isNotEmpty)
      .toSet();

  if (!existingColumns.contains('Gender')) {
    await db.execute('ALTER TABLE Pet ADD COLUMN Gender TEXT;');
  }
}

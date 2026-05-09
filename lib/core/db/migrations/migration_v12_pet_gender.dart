import 'package:sqflite/sqflite.dart';

Future<void> migrateV12PetGender(Database db) async {
  final tableInfo = await db.rawQuery("PRAGMA table_info('Pet');");
  final existingColumns = tableInfo
      .map((row) => (row['name'] as String?) ?? '')
      .where((column) => column.isNotEmpty)
      .toSet();

  if (!existingColumns.contains('Gender')) {
    await db.execute('ALTER TABLE Pet ADD COLUMN Gender TEXT;');
  }
}
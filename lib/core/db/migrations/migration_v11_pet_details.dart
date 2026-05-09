import 'package:sqflite/sqflite.dart';

Future<void> migrateV11PetDetails(Database db) async {
  final tableInfo = await db.rawQuery("PRAGMA table_info('Pet');");
  final existingColumns = tableInfo
      .map((row) => (row['name'] as String?) ?? '')
      .where((column) => column.isNotEmpty)
      .toSet();

  Future<void> addColumnIfMissing(String columnName, String sql) async {
    if (!existingColumns.contains(columnName)) {
      await db.execute(sql);
    }
  }

  await addColumnIfMissing('Age', 'ALTER TABLE Pet ADD COLUMN Age INTEGER;');
  await addColumnIfMissing('Personality', 'ALTER TABLE Pet ADD COLUMN Personality TEXT;');
  await addColumnIfMissing('IsDewormed', 'ALTER TABLE Pet ADD COLUMN IsDewormed INTEGER NOT NULL DEFAULT 0;');
  await addColumnIfMissing('IsVaccinated', 'ALTER TABLE Pet ADD COLUMN IsVaccinated INTEGER NOT NULL DEFAULT 0;');
  await addColumnIfMissing('ImageURL', 'ALTER TABLE Pet ADD COLUMN ImageURL TEXT;');
}
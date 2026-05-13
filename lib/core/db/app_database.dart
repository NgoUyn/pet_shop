import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'db_migrations.dart';
import 'db_open_repairs.dart';
import 'db_schema.dart';
import 'db_seed.dart';
import 'db_user_cleanup.dart';
import 'migrations/migration_v13_favorites_and_notifications.dart';

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
      version: 18,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onOpen: (db) async {
        await runOpenRepairs(db);
      },
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await createBaseSchema(db);

        await MigrationV13FavoritesAndNotifications.up(db);
        await seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await runMigrations(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> deleteUserById(int userId) async {
    final db = await instance;
    await deleteUserByIdFromDb(db, userId);
  }
}
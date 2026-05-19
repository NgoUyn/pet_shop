import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV21CategoryTypes {
  static Future<void> up(Database db) async {
    // ── 1. Create PetBreedCategory table ───────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS PetBreedCategory (
        BreedID INTEGER PRIMARY KEY AUTOINCREMENT,
        Species TEXT NOT NULL CHECK (Species IN ('Chó', 'Mèo', 'Khác')),
        BreedName TEXT NOT NULL,
        Description TEXT,
        IsActive INTEGER NOT NULL DEFAULT 1 CHECK (IsActive IN (0, 1)),
        CreatedAt TEXT NOT NULL,
        UNIQUE(Species, BreedName)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_breed_species ON PetBreedCategory(Species);',
    );

    // ── 2. Create ProductSubCategory table ─────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ProductSubCategory (
        SubCategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
        SubCategoryName TEXT NOT NULL UNIQUE,
        Description TEXT,
        IsActive INTEGER NOT NULL DEFAULT 1 CHECK (IsActive IN (0, 1)),
        CreatedAt TEXT NOT NULL
      );
    ''');

    // ── 3. Add SubCategoryID column to Product ─────────────────────────────
    try {
      await db.execute(
        'ALTER TABLE Product ADD COLUMN SubCategoryID INTEGER REFERENCES ProductSubCategory(SubCategoryID);',
      );
    } catch (_) {}

    // ── 4. Seed PetBreedCategory ────────────────────────────────────────────
    final now = DateTime.now().toIso8601String();
    final breeds = [
      ('Chó', 'Poodle', 'Chó Poodle xù lông'),
      ('Chó', 'Husky', 'Chó Husky mắt xanh'),
      ('Chó', 'Golden Retriever', 'Chó Golden Retriever thân thiện'),
      ('Chó', 'Shiba Inu', 'Chó Shiba Inu Nhật Bản'),
      ('Chó', 'Corgi', 'Chó Corgi chân ngắn'),
      ('Chó', 'Chihuahua', 'Chó Chihuahua nhỏ nhắn'),
      ('Chó', 'Phối giống', 'Chó phối giống'),
      ('Mèo', 'Anh lông ngắn', 'Mèo Anh lông ngắn (BSH)'),
      ('Mèo', 'Ba Tư', 'Mèo Ba Tư lông dài'),
      ('Mèo', 'Maine Coon', 'Mèo Maine Coon cỡ lớn'),
      ('Mèo', 'Ragdoll', 'Mèo Ragdoll hiền lành'),
      ('Mèo', 'Munchkin', 'Mèo Munchkin chân ngắn'),
      ('Mèo', 'Scottish Fold', 'Mèo Scottish Fold tai cụp'),
      ('Mèo', 'Phối giống', 'Mèo phối giống'),
      ('Khác', 'Thỏ', 'Thỏ cảnh'),
      ('Khác', 'Hamster', 'Chuột hamster'),
      ('Khác', 'Chim', 'Chim cảnh'),
    ];

    for (final (species, breedName, desc) in breeds) {
      await db.insert(
        'PetBreedCategory',
        {
          'Species': species,
          'BreedName': breedName,
          'Description': desc,
          'IsActive': 1,
          'CreatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // ── 5. Seed ProductSubCategory ──────────────────────────────────────────
    final subCats = [
      ('Thức ăn', 'Thức ăn cho thú cưng'),
      ('Vật dụng ăn uống', 'Bát, bình nước, khay ăn'),
      ('Đồ chơi', 'Đồ chơi cho thú cưng'),
      ('Vòng cổ & Dây dắt', 'Phụ kiện dắt thú cưng'),
      ('Nhà & Giường ngủ', 'Nhà, lồng, chuồng, nệm'),
      ('Vệ sinh & Chăm sóc', 'Sữa tắm, lược, kéo cắt'),
      ('Quần áo & Trang phục', 'Áo, nón, giày cho thú cưng'),
      ('Khác', 'Phụ kiện khác'),
    ];

    for (final (name, desc) in subCats) {
      await db.insert(
        'ProductSubCategory',
        {
          'SubCategoryName': name,
          'Description': desc,
          'IsActive': 1,
          'CreatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // ── 6. Sync to Firestore ────────────────────────────────────────────────
    await _syncToFirestore(db);
  }

  static Future<void> _syncToFirestore(Database db) async {
    try {
      final breeds = await db.query('PetBreedCategory');
      for (final row in breeds) {
        await FirebaseFirestore.instance
            .collection('petBreedCategories')
            .doc(row['BreedID'].toString())
            .set({
          'breedId': row['BreedID'] as int,
          'species': row['Species'] as String,
          'breedName': row['BreedName'] as String,
          'description': row['Description'] as String?,
          'isActive': (row['IsActive'] as int) == 1,
          'createdAt': row['CreatedAt'] as String,
        });
      }

      final subCats = await db.query('ProductSubCategory');
      for (final row in subCats) {
        await FirebaseFirestore.instance
            .collection('productSubCategories')
            .doc(row['SubCategoryID'].toString())
            .set({
          'subCategoryId': row['SubCategoryID'] as int,
          'subCategoryName': row['SubCategoryName'] as String,
          'description': row['Description'] as String?,
          'isActive': (row['IsActive'] as int) == 1,
          'createdAt': row['CreatedAt'] as String,
        });
      }
    } catch (e) {
      print('MigrationV21CategoryTypes._syncToFirestore error: $e');
    }
  }
}

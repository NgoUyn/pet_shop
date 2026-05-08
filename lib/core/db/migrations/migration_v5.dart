import 'package:sqflite/sqflite.dart';

Future<void> migrateV5(Database db) async {
  print('migration_v5: start');
  final productCountRows = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Product;');
  final petCountRows = await db.rawQuery('SELECT COUNT(*) AS Cnt FROM Pet;');

  final productCount = (productCountRows.first['Cnt'] as int?) ?? 0;
  final petCount = (petCountRows.first['Cnt'] as int?) ?? 0;

  if (productCount == 0) {
    await db.insert(
      'Category',
      {
        'CategoryName': 'Thức ăn thú cưng',
        'Description': 'Các loại thức ăn cho chó mèo',
        'ParentCategoryID': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'Category',
      {
        'CategoryName': 'Phụ kiện',
        'Description': 'Phụ kiện cho thú cưng',
        'ParentCategoryID': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final categoryRows = await db.query(
      'Category',
      columns: ['CategoryID', 'CategoryName'],
      where: 'CategoryName IN (?, ?)',
      whereArgs: ['Thức ăn thú cưng', 'Phụ kiện'],
    );

    int? foodCategoryId;
    int? accessoryCategoryId;
    for (final row in categoryRows) {
      final name = row['CategoryName'] as String?;
      final id = row['CategoryID'] as int?;
      if (name == 'Thức ăn thú cưng') foodCategoryId = id;
      if (name == 'Phụ kiện') accessoryCategoryId = id;
    }

    final now = DateTime.now().toIso8601String();

    final products = [
      {
        'CategoryID': foodCategoryId ?? 1,
        'ProductName': 'Hạt cho chó Royal Canin',
        'Price': 250000.0,
        'StockQuantity': 20,
        'Description': 'Thức ăn cao cấp cho chó',
        'ImageURL': '',
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
      {
        'CategoryID': foodCategoryId ?? 1,
        'ProductName': 'Pate cho mèo Whiskas',
        'Price': 35000.0,
        'StockQuantity': 50,
        'Description': 'Pate vị cá ngừ',
        'ImageURL': '',
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
      {
        'CategoryID': accessoryCategoryId ?? 2,
        'ProductName': 'Vòng cổ chó',
        'Price': 80000.0,
        'StockQuantity': 30,
        'Description': 'Vòng cổ da mềm',
        'ImageURL': '',
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
      {
        'CategoryID': accessoryCategoryId ?? 2,
        'ProductName': 'Dây dắt thú cưng',
        'Price': 120000.0,
        'StockQuantity': 25,
        'Description': 'Dây dắt chắc chắn',
        'ImageURL': '',
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
    ];

    for (final product in products) {
      await db.insert('Product', product);
    }
  }

  if (petCount == 0) {
    final customerRows = await db.query(
      'Customer',
      columns: ['CustomerID'],
      limit: 1,
    );
    final customerId = customerRows.isEmpty ? null : customerRows.first['CustomerID'] as int?;
    final now = DateTime.now().toIso8601String();

    final pets = [
      {
        'CustomerID': customerId,
        'PetName': 'Milu',
        'Species': 'Chó Poodle',
        'Description': 'Poodle trắng, 2 tháng tuổi',
        'Price': 3500000.0,
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
      {
        'CustomerID': customerId,
        'PetName': 'Tom',
        'Species': 'Mèo Anh lông ngắn',
        'Description': 'Mèo xám dễ thương',
        'Price': 4200000.0,
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
      {
        'CustomerID': customerId,
        'PetName': 'Max',
        'Species': 'Chó Husky',
        'Description': 'Mắt xanh cực đẹp',
        'Price': 8000000.0,
        'IsActive': 1,
        'CreatedAt': now,
        'UpdatedAt': null,
      },
    ];

    for (final pet in pets) {
      await db.insert('Pet', pet);
    }
  print('migration_v5: done');
  }
}

import 'package:sqflite/sqflite.dart';

Future<void> seedInitialData(Database db) async {
  await db.insert('User', {
    'Role': 'customer',
    'Email': 'emgaikwai@gmail.com',
    'PasswordHash': 'hash_customer',
    'FullName': 'Customer Test',
    'IsActive': 1,
    'VerificationToken': null,
    'VerifiedAt': null,
    'CreatedAt': DateTime.now().toIso8601String(),
    'UpdatedAt': null,
  });

  await db.insert('User', {
    'Role': 'admin',
    'Email': 'huynhmai2755@gmail.com',
    'PasswordHash': 'hash_admin',
    'FullName': 'Admin Shop',
    'IsActive': 1,
    'VerificationToken': null,
    'VerifiedAt': null,
    'CreatedAt': DateTime.now().toIso8601String(),
    'UpdatedAt': null,
  });

  await db.insert('User', {
    'Role': 'admin',
    'Email': 'sugaryummy321@gmail.com',
    'PasswordHash': 'hash_admin',
    'FullName': 'Admin Shop',
    'IsActive': 1,
    'VerificationToken': null,
    'VerifiedAt': null,
    'CreatedAt': DateTime.now().toIso8601String(),
    'UpdatedAt': null,
  });

  await db.insert('Customer', {
    'UserID': 1,
    'Phone': '0123456789',
    'Address': 'Ho Chi Minh City',
    'LoyaltyPoints': 100,
  });

  await db.insert('Category', {
    'CategoryName': 'Thức ăn thú cưng',
    'Description': 'Các loại thức ăn cho chó mèo',
    'ParentCategoryID': null,
  });

  await db.insert('Category', {
    'CategoryName': 'Phụ kiện',
    'Description': 'Phụ kiện cho thú cưng',
    'ParentCategoryID': null,
  });

  final now = DateTime.now().toIso8601String();

  final products = [
    {
      'CategoryID': 1,
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
      'CategoryID': 1,
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
      'CategoryID': 2,
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
      'CategoryID': 2,
      'ProductName': 'Dây dắt thú cưng',
      'Price': 120000.0,
      'StockQuantity': 25,
      'Description': 'Dây dắt chắc chắn',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 1,
      'ProductName': 'Sữa tắm chó mèo',
      'Price': 95000.0,
      'StockQuantity': 40,
      'Description': 'Sữa tắm khử mùi',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 2,
      'ProductName': 'Khay vệ sinh mèo',
      'Price': 180000.0,
      'StockQuantity': 15,
      'Description': 'Khay vệ sinh chống bắn cát',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 1,
      'ProductName': 'Cát vệ sinh mèo',
      'Price': 70000.0,
      'StockQuantity': 60,
      'Description': 'Cát khử mùi hương lavender',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 2,
      'ProductName': 'Nhà ngủ cho mèo',
      'Price': 320000.0,
      'StockQuantity': 10,
      'Description': 'Nhà ngủ mềm mại',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 2,
      'ProductName': 'Bát ăn inox',
      'Price': 45000.0,
      'StockQuantity': 70,
      'Description': 'Bát ăn chống gỉ',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CategoryID': 1,
      'ProductName': 'Vitamin cho chó mèo',
      'Price': 150000.0,
      'StockQuantity': 18,
      'Description': 'Vitamin tăng sức đề kháng',
      'ImageURL': '',
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
  ];

  for (final product in products) {
    await db.insert('Product', product);
  }

  final pets = [
    {
      'CustomerID': 1,
      'PetName': 'Milu',
      'Species': 'Chó Poodle',
      'Description': 'Poodle trắng, 2 tháng tuổi',
      'Price': 3500000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Tom',
      'Species': 'Mèo Anh lông ngắn',
      'Description': 'Mèo xám dễ thương',
      'Price': 4200000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Bibi',
      'Species': 'Chó Corgi',
      'Description': 'Corgi chân ngắn',
      'Price': 7000000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Luna',
      'Species': 'Mèo Ba Tư',
      'Description': 'Lông dài trắng',
      'Price': 5500000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Max',
      'Species': 'Chó Husky',
      'Description': 'Mắt xanh cực đẹp',
      'Price': 8000000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Nabi',
      'Species': 'Mèo Scottish',
      'Description': 'Tai cụp đáng yêu',
      'Price': 6000000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Coco',
      'Species': 'Chó Chihuahua',
      'Description': 'Nhỏ nhắn lanh lợi',
      'Price': 2800000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Mimi',
      'Species': 'Mèo Munchkin',
      'Description': 'Chân ngắn siêu cute',
      'Price': 7500000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Rocky',
      'Species': 'Chó Golden',
      'Description': 'Hiền lành thân thiện',
      'Price': 6500000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
    {
      'CustomerID': 1,
      'PetName': 'Snow',
      'Species': 'Mèo Ragdoll',
      'Description': 'Lông trắng xanh mắt',
      'Price': 9000000.0,
      'IsActive': 1,
      'CreatedAt': now,
      'UpdatedAt': null,
    },
  ];

  for (final pet in pets) {
    await db.insert('Pet', pet);
  }

  // Seed sample notifications
  await db.insert('AppNotification', {
    'UserID': 1,
    'Type': 'order',
    'Title': 'Đơn hàng được xác nhận',
    'Content': 'Đơn hàng #001 của bạn đã được xác nhận',
    'CreatedAt': DateTime.now().toIso8601String(),
    'IsRead': 0,
    'ReadAt': null,
    'ReferenceID': null,
    'ReferenceType': 'order',
  });

  await db.insert('AppNotification', {
    'UserID': 1,
    'Type': 'general',
    'Title': 'Chào mừng đến Pet Shop',
    'Content': 'Cảm ơn bạn đã tham gia cộng đồng của chúng tôi',
    'CreatedAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    'IsRead': 0,
    'ReadAt': null,
    'ReferenceID': null,
    'ReferenceType': null,
  });

  await db.insert('AppNotification', {
    'UserID': 1,
    'Type': 'promotion',
    'Title': 'Khuyến mãi mới: Giảm 20% cho sản phẩm',
    'Content': 'Tất cả sản phẩm được giảm giá 20% trong 24 giờ',
    'CreatedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'IsRead': 1,
    'ReadAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'ReferenceID': null,
    'ReferenceType': null,
  });
}

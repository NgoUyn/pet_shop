import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';

class ProductItem {
  ProductItem({
    required this.productId,
    required this.categoryId,
    required this.productName,
    required this.price,
    required this.stockQuantity,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.imageUrl,
  });

  final int productId;
  final int categoryId;
  final String productName;
  final double price;
  final int stockQuantity;
  final bool isActive;
  final DateTime createdAt;
  final String? description;
  final String? imageUrl;

  static ProductItem fromRow(Map<String, Object?> row) {
    return ProductItem(
      productId: row['ProductID'] as int,
      categoryId: row['CategoryID'] as int,
      productName: (row['ProductName'] as String?) ?? '',
      price: (row['Price'] as num).toDouble(),
      stockQuantity: (row['StockQuantity'] as int?) ?? 0,
      description: row['Description'] as String?,
      imageUrl: row['ImageURL'] as String?,
      isActive: (row['IsActive'] as int?) == 1,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
    );
  }
}

class ProductRepository {
  ProductRepository._();

  static final ProductRepository instance = ProductRepository._();
  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notifyChanged() {
    changeToken.value = changeToken.value + 1;
  }

  Future<List<ProductItem>> listActiveProducts({int limit = 200}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Product',
      where: 'IsActive = 1',
      orderBy: 'CreatedAt DESC, ProductID DESC',
      limit: limit,
    );

    return rows.map(ProductItem.fromRow).toList();
  }

  Future<ProductItem?> getProductById(int productId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Product',
      where: 'ProductID = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ProductItem.fromRow(rows.first);
  }

  Future<int> addProduct({
    required int categoryId,
    required String productName,
    required double price,
    required int stockQuantity,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('Product', {
      'CategoryID': categoryId,
      'ProductName': productName,
      'Price': price,
      'StockQuantity': stockQuantity,
      'Description': description,
      'ImageURL': imageUrl,
      'IsActive': isActive ? 1 : 0,
      'CreatedAt': now,
      'UpdatedAt': null,
    });
    _notifyChanged();
    return id;
  }

  Future<ProductItem> updateProduct({
    required int productId,
    required int categoryId,
    required String productName,
    required double price,
    required int stockQuantity,
    String? description,
    String? imageUrl,
    bool? isActive,
  }) async {
    final db = await AppDatabase.instance;
    final current = await getProductById(productId);
    final nextIsActive = isActive ?? current?.isActive ?? true;
    await db.update(
      'Product',
      {
        'CategoryID': categoryId,
        'ProductName': productName,
        'Price': price,
        'StockQuantity': stockQuantity,
        'Description': description,
        'ImageURL': imageUrl,
        'IsActive': nextIsActive ? 1 : 0,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'ProductID = ?',
      whereArgs: [productId],
    );

    final rows = await db.query(
      'Product',
      where: 'ProductID = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Không tìm thấy sản phẩm cần cập nhật');
    }

    _notifyChanged();
    return ProductItem.fromRow(rows.first);
  }

  Future<void> deleteProduct(int productId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'Product',
      {
        'IsActive': 0,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'ProductID = ?',
      whereArgs: [productId],
    );
    _notifyChanged();
  }

  Future<String?> getCategoryName(int categoryId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Category',
      columns: ['CategoryName'],
      where: 'CategoryID = ?',
      whereArgs: [categoryId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['CategoryName'] as String?;
  }
}

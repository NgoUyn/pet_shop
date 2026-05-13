import 'package:cloud_firestore/cloud_firestore.dart';
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
    final results = await Future.wait([
      _listLocalActiveProducts(limit),
      _listFirestoreActiveProducts(limit),
    ]);

    final localItems = results[0] as List<ProductItem>;
    final firestoreItems = results[1] as List<ProductItem>;

    // Dedup by productId (Firestore takes precedence for same ID)
    final map = <int, ProductItem>{};
    for (final item in localItems) {
      map[item.productId] = item;
    }
    for (final item in firestoreItems) {
      map[item.productId] = item;
    }

    var merged = map.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit < merged.length) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  Future<List<ProductItem>> _listLocalActiveProducts(int limit) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Product',
      where: 'IsActive = 1',
      orderBy: 'CreatedAt DESC, ProductID DESC',
      limit: limit,
    );
    return rows.map(ProductItem.fromRow).toList();
  }

  Future<List<ProductItem>> _listFirestoreActiveProducts(int limit) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ProductItem(
          productId: (data['productId'] as num).toInt(),
          categoryId: (data['categoryId'] as num).toInt(),
          productName: (data['productName'] as String?) ?? '',
          price: (data['price'] as num).toDouble(),
          stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
          description: data['description'] as String?,
          imageUrl: data['imageUrl'] as String?,
          isActive: data['isActive'] as bool? ?? true,
          createdAt: DateTime.parse((data['createdAt'] as String)),
        );
      }).toList();
    } catch (e) {
      print('ProductRepository._listFirestoreActiveProducts error: $e');
      return [];
    }
  }

  Future<ProductItem?> getProductById(int productId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Product',
      where: 'ProductID = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return ProductItem.fromRow(rows.first);
    }

    // Fallback to Firestore (may have been created on another device)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId.toString())
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return ProductItem(
        productId: productId,
        categoryId: (data['categoryId'] as num).toInt(),
        productName: (data['productName'] as String?) ?? '',
        price: (data['price'] as num).toDouble(),
        stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
        description: data['description'] as String?,
        imageUrl: data['imageUrl'] as String?,
        isActive: data['isActive'] as bool? ?? true,
        createdAt: DateTime.parse((data['createdAt'] as String)),
      );
    } catch (e) {
      print('ProductRepository.getProductById Firestore fallback error: $e');
      return null;
    }
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
    _syncProductToFirestore(ProductItem(
      productId: id,
      categoryId: categoryId,
      productName: productName,
      price: price,
      stockQuantity: stockQuantity,
      description: description,
      imageUrl: imageUrl,
      isActive: isActive,
      createdAt: DateTime.parse(now),
    ));
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

    final product = ProductItem.fromRow(rows.first);
    _syncProductToFirestore(product);
    _notifyChanged();
    return product;
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
    _syncProductDeletionToFirestore(productId);
    _notifyChanged();
  }

  // ── Firestore sync ──────────────────────────────────────────────────

  void _syncProductToFirestore(ProductItem product) {
    _doSyncProductToFirestore(product);
  }

  Future<void> _doSyncProductToFirestore(ProductItem product) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.productId.toString())
          .set({
        'productId': product.productId,
        'categoryId': product.categoryId,
        'productName': product.productName,
        'price': product.price,
        'stockQuantity': product.stockQuantity,
        'description': product.description,
        'imageUrl': product.imageUrl,
        'isActive': product.isActive,
        'createdAt': product.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('ProductRepository._doSyncProductToFirestore error: $e');
    }
  }

  Future<void> _syncProductDeletionToFirestore(int productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId.toString())
          .update({'isActive': false});
    } catch (e) {
      print('ProductRepository._syncProductDeletionToFirestore error: $e');
    }
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

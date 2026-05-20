import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/product_provider.dart';

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
    this.subCategoryId,
    this.status = 'Đang bán',
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
  final int? subCategoryId;
  final String status;

  static ProductItem fromRow(Map<String, Object?> row) {
    final rawStatus = row['Status'] as String?;
    final isActive = (row['IsActive'] as int?) == 1;
    final stockQuantity = (row['StockQuantity'] as int?) ?? 0;

    // Derive status if not explicitly set
    String status;
    if (rawStatus != null && rawStatus.isNotEmpty) {
      status = rawStatus;
    } else if (!isActive) {
      status = 'Ngưng bán';
    } else if (stockQuantity < 5) {
      status = 'Hết hàng';
    } else {
      status = 'Đang bán';
    }

    return ProductItem(
      productId: row['ProductID'] as int,
      categoryId: row['CategoryID'] as int,
      productName: (row['ProductName'] as String?) ?? '',
      price: (row['Price'] as num).toDouble(),
      stockQuantity: stockQuantity,
      description: row['Description'] as String?,
      imageUrl: row['ImageURL'] as String?,
      isActive: isActive,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
      subCategoryId: row['SubCategoryID'] as int?,
      status: status,
    );
  }
}

class ProductRepository {
  ProductRepository._();

  static final ProductRepository instance = ProductRepository._();
  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notifyChanged() {
    changeToken.value = changeToken.value + 1;
    // Also trigger ProductProvider to reload
    ProductProvider.instance.reload();
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
        final isActive = data['isActive'] as bool? ?? true;
        final stockQuantity = (data['stockQuantity'] as num?)?.toInt() ?? 0;
        final rawStatus = (data['status'] as String?) ?? '';
        final status = rawStatus.isNotEmpty
            ? rawStatus
            : deriveStatus(stockQuantity: stockQuantity, isActive: isActive);
        return ProductItem(
          productId: (data['productId'] as num).toInt(),
          categoryId: (data['categoryId'] as num).toInt(),
          productName: (data['productName'] as String?) ?? '',
          price: (data['price'] as num).toDouble(),
          stockQuantity: stockQuantity,
          description: data['description'] as String?,
          imageUrl: data['imageUrl'] as String?,
          isActive: isActive,
          subCategoryId: (data['subCategoryId'] as num?)?.toInt(),
          createdAt: DateTime.parse((data['createdAt'] as String)),
          status: status,
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
      final isActive = data['isActive'] as bool? ?? true;
      final stockQuantity = (data['stockQuantity'] as num?)?.toInt() ?? 0;
      final rawStatus = (data['status'] as String?) ?? '';
      final status = rawStatus.isNotEmpty
          ? rawStatus
          : deriveStatus(stockQuantity: stockQuantity, isActive: isActive);
      return ProductItem(
        productId: productId,
        categoryId: (data['categoryId'] as num).toInt(),
        productName: (data['productName'] as String?) ?? '',
        price: (data['price'] as num).toDouble(),
        stockQuantity: stockQuantity,
        description: data['description'] as String?,
        imageUrl: data['imageUrl'] as String?,
        isActive: isActive,
        subCategoryId: (data['subCategoryId'] as num?)?.toInt(),
        createdAt: DateTime.parse((data['createdAt'] as String)),
        status: status,
      );
    } catch (e) {
      print('ProductRepository.getProductById Firestore fallback error: $e');
      return null;
    }
  }

  /// Derive status from stock quantity and isActive
  static String deriveStatus({required int stockQuantity, required bool isActive}) {
    if (!isActive) return 'Ngưng bán';
    if (stockQuantity < 5) return 'Hết hàng';
    return 'Đang bán';
  }

  Future<int> addProduct({
    required int categoryId,
    required String productName,
    required double price,
    required int stockQuantity,
    String? description,
    String? imageUrl,
    bool isActive = true,
    int? subCategoryId,
    String? status,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();
    final forcedStatus = deriveStatus(stockQuantity: stockQuantity, isActive: isActive);
    final derivedStatus = (status ?? forcedStatus) == 'Đang bán' && forcedStatus == 'Hết hàng'
      ? forcedStatus
      : (status ?? forcedStatus);
    final id = await db.insert('Product', {
      'CategoryID': categoryId,
      'ProductName': productName,
      'Price': price,
      'StockQuantity': stockQuantity,
      'Description': description,
      'ImageURL': imageUrl,
      'IsActive': isActive ? 1 : 0,
      'SubCategoryID': subCategoryId,
      'Status': derivedStatus,
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
      subCategoryId: subCategoryId,
      status: derivedStatus,
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
    int? subCategoryId,
    String? status,
  }) async {
    final db = await AppDatabase.instance;
    final current = await getProductById(productId);
    final nextIsActive = isActive ?? current?.isActive ?? true;
    final forcedStatus = deriveStatus(stockQuantity: stockQuantity, isActive: nextIsActive);
    final nextStatus = (status ?? forcedStatus) == 'Đang bán' && forcedStatus == 'Hết hàng'
      ? forcedStatus
      : (status ?? forcedStatus);

    final updateValues = <String, Object?>{
      'CategoryID': categoryId,
      'ProductName': productName,
      'Price': price,
      'StockQuantity': stockQuantity,
      'Description': description,
      'ImageURL': imageUrl,
      'IsActive': nextIsActive ? 1 : 0,
      'SubCategoryID': subCategoryId,
      'Status': nextStatus,
      'UpdatedAt': DateTime.now().toIso8601String(),
    };

    await db.update(
      'Product',
      updateValues,
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

  /// Update only the status of a product (used for auto-status changes)
  Future<void> updateProductStatus(int productId, String status) async {
    final db = await AppDatabase.instance;
    await db.update(
      'Product',
      {
        'Status': status,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'ProductID = ?',
      whereArgs: [productId],
    );
    // Sync to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId.toString())
          .update({'status': status, 'isActive': status != 'Ngưng bán'});
    } catch (e) {
      print('ProductRepository.updateProductStatus Firestore error: $e');
    }
    _notifyChanged();
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
        'status': product.status,
        'subCategoryId': product.subCategoryId,
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

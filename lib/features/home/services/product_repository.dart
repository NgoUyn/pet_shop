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

  Future<List<ProductItem>> listActiveProducts({int limit = 200}) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Product',
      orderBy: 'CreatedAt DESC, ProductID DESC',
      limit: limit,
    );

    return rows.map(ProductItem.fromRow).toList();
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

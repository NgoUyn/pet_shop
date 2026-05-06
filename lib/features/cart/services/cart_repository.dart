import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';

class CartProductEntry {
  CartProductEntry({
    required this.cartItemId,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.addedAt,
    this.stockQuantity = 0,
  });

  final int cartItemId;
  final int productId;
  final String productName;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final DateTime addedAt;
  final int stockQuantity;

  double get lineTotal => unitPrice * quantity;

  static CartProductEntry fromRow(Map<String, Object?> row) {
    return CartProductEntry(
      cartItemId: row['CartItemID'] as int,
      productId: row['ProductID'] as int,
      productName: (row['ProductName'] as String?) ?? '',
      imageUrl: row['ImageURL'] as String?,
      unitPrice: (row['UnitPrice'] as num).toDouble(),
      quantity: (row['Quantity'] as int?) ?? 1,
      addedAt: DateTime.parse(row['AddedAt'] as String),
      stockQuantity: (row['StockQuantity'] as int?) ?? 0,
    );
  }
}

class CartRepository {
  CartRepository._();

  static final CartRepository instance = CartRepository._();

  final ValueNotifier<int> cartCount = ValueNotifier<int>(0);

  Future<int> _resolveCustomerId(int userId) async {
    final db = await AppDatabase.instance;

    final rows = await db.query(
      'Customer',
      columns: ['CustomerID'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['CustomerID'] as int;
    }

    final inserted = await db.insert('Customer', {
      'UserID': userId,
      'Phone': null,
      'Address': null,
      'LoyaltyPoints': 0,
    });

    return inserted;
  }

  Future<int> _ensureCartIdForCustomer(int customerId, {required DatabaseExecutor txnOrDb}) async {
    final rows = await txnOrDb.query(
      'Cart',
      columns: ['CartID'],
      where: 'CustomerID = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['CartID'] as int;
    }

    final now = DateTime.now().toIso8601String();
    final cartId = await txnOrDb.insert('Cart', {
      'CustomerID': customerId,
      'CreatedAt': now,
      'UpdatedAt': now,
    });

    return cartId;
  }

  Future<void> refreshCountForCurrentUser() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      cartCount.value = 0;
      return;
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);
    final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: db);

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(Quantity), 0) AS Total FROM CartItem WHERE CartID = ?',
      [cartId],
    );

    final total = (rows.first['Total'] as int?) ?? 0;
    cartCount.value = total;
  }

  Future<void> addProductToCart({required int productId, int quantity = 1}) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thêm vào giỏ hàng');
    }

    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantity phải > 0');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);

    await db.transaction((txn) async {
      final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

      final productRows = await txn.query(
        'Product',
        columns: ['Price', 'StockQuantity'],
        where: 'ProductID = ?',
        whereArgs: [productId],
        limit: 1,
      );

      if (productRows.isEmpty) {
        throw StateError('Không tìm thấy sản phẩm để thêm vào giỏ hàng');
      }

      final unitPrice = (productRows.first['Price'] as num).toDouble();
      final stock = (productRows.first['StockQuantity'] as int?) ?? 0;

      final existingRows = await txn.query(
        'CartItem',
        columns: ['CartItemID', 'Quantity'],
        where: 'CartID = ? AND ProductID = ?',
        whereArgs: [cartId, productId],
        limit: 1,
      );

      final now = DateTime.now().toIso8601String();

      if (existingRows.isNotEmpty) {
        final cartItemId = existingRows.first['CartItemID'] as int;
        final currentQty = (existingRows.first['Quantity'] as int?) ?? 1;
        final newQty = currentQty + quantity;

        if (newQty > stock) {
          throw StateError('Số lượng vượt quá tồn kho (Hiện có: $stock)');
        }

        await txn.update(
          'CartItem',
          {
            'Quantity': newQty,
          },
          where: 'CartItemID = ?',
          whereArgs: [cartItemId],
        );
      } else {
        if (quantity > stock) {
          throw StateError('Số lượng vượt quá tồn kho (Hiện có: $stock)');
        }
        await txn.insert('CartItem', {
          'CartID': cartId,
          'ProductID': productId,
          'PetID': null,
          'Quantity': quantity,
          'UnitPrice': unitPrice,
          'AddedAt': now,
        });
      }

      await txn.update(
        'Cart',
        {'UpdatedAt': now},
        where: 'CartID = ?',
        whereArgs: [cartId],
      );
    });

    await refreshCountForCurrentUser();
  }

  Future<void> updateQuantity(int cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final itemRows = await txn.rawQuery('''
        SELECT ci.ProductID, p.StockQuantity 
        FROM CartItem ci 
        JOIN Product p ON ci.ProductID = p.ProductID 
        WHERE ci.CartItemID = ?
      ''', [cartItemId]);

      if (itemRows.isEmpty) throw StateError('Không tìm thấy sản phẩm trong giỏ');

      final stock = (itemRows.first['StockQuantity'] as int?) ?? 0;
      if (newQuantity > stock) {
        throw StateError('Số lượng tồn kho không đủ (Hiện có: $stock)');
      }

      await txn.update(
        'CartItem',
        {'Quantity': newQuantity},
        where: 'CartItemID = ?',
        whereArgs: [cartItemId],
      );
    });
    await refreshCountForCurrentUser();
  }

  Future<void> removeFromCart(int cartItemId) async {
    final db = await AppDatabase.instance;
    await db.delete('CartItem', where: 'CartItemID = ?', whereArgs: [cartItemId]);
    await refreshCountForCurrentUser();
  }

  Future<List<CartProductEntry>> listProductEntriesForCurrentUser() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      return [];
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);
    final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: db);

    final rows = await db.rawQuery(
      '''
      SELECT
        ci.CartItemID,
        ci.ProductID,
        p.ProductName,
        p.ImageURL,
        p.StockQuantity,
        ci.UnitPrice,
        ci.Quantity,
        ci.AddedAt
      FROM CartItem ci
      JOIN Product p ON p.ProductID = ci.ProductID
      WHERE ci.CartID = ? AND ci.ProductID IS NOT NULL
      ORDER BY ci.AddedAt DESC, ci.CartItemID DESC
      ''',
      [cartId],
    );

    return rows.map(CartProductEntry.fromRow).toList();
  }
}

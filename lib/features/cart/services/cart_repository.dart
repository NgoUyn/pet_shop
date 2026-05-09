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

class CheckoutResult {
  CheckoutResult({
    required this.invoiceId,
    required this.totalItems,
    required this.totalAmount,
    required this.discountAmount,
    required this.usedPoints,
    required this.earnedPoints,
  });

  final int invoiceId;
  final int totalItems;
  final double totalAmount;
  final double discountAmount;
  final int usedPoints;
  final int earnedPoints;
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

    final rows = await db.query(
      'CartItem',
      columns: ['CartItemID'],
      where: 'CartID = ? AND ProductID IS NOT NULL',
      whereArgs: [cartId],
    );
    cartCount.value = rows.length;
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

  /// Creates a pending order (Unpaid) for online payment without deducting stock.
  /// Returns the invoice ID.
  Future<int> createPendingOrder({
    required String? shippingAddress,
    required bool useLoyaltyPoints,
  }) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thanh toán');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);

    return await db.transaction<int>((txn) async {
      final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

      final cartItems = await txn.rawQuery(
        '''
        SELECT
          ci.CartItemID,
          ci.ProductID,
          ci.Quantity,
          ci.UnitPrice,
          p.ProductName,
          p.StockQuantity
        FROM CartItem ci
        JOIN Product p ON p.ProductID = ci.ProductID
        WHERE ci.CartID = ? AND ci.ProductID IS NOT NULL
        ORDER BY ci.AddedAt DESC, ci.CartItemID DESC
        ''',
        [cartId],
      );

      if (cartItems.isEmpty) {
        throw StateError('Giỏ hàng đang trống');
      }

      var totalAmount = 0.0;
      var discountAmount = 0.0;
      var usedPoints = 0;

      // Validate items and compute totals
      for (final row in cartItems) {
        if (row['ProductID'] == null) throw StateError('Một mục giỏ hàng thiếu ProductID');
        if (row['Quantity'] == null) throw StateError('Một mục giỏ hàng thiếu Quantity');

        final stock = (row['StockQuantity'] as int?) ?? 0;
        final quantity = (row['Quantity'] as int?) ?? 0;
        final productName = (row['ProductName'] as String?) ?? 'Sản phẩm';

        if (quantity <= 0) {
          throw StateError('Dữ liệu giỏ hàng không hợp lệ');
        }

        if (stock < quantity) {
          throw StateError('Sản phẩm "$productName" không đủ tồn kho');
        }

        final unitPrice = (row['UnitPrice'] as num).toDouble();
        totalAmount += (quantity * unitPrice);
      }

      // Handle loyalty points
      final customerRows = await txn.query(
        'Customer',
        columns: ['LoyaltyPoints'],
        where: 'CustomerID = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      final currentLoyaltyPoints = customerRows.isNotEmpty
          ? ((customerRows.first['LoyaltyPoints'] as int?) ?? 0)
          : 0;

      if (useLoyaltyPoints && currentLoyaltyPoints >= 50) {
        final redeemableBlocks = currentLoyaltyPoints ~/ 50;
        final maxBlocksByAmount = (totalAmount / 5000).floor();
        final blocksToUse = redeemableBlocks > maxBlocksByAmount
            ? maxBlocksByAmount
            : redeemableBlocks;
        usedPoints = blocksToUse * 50;
        discountAmount = blocksToUse * 5000.0;
        totalAmount = totalAmount - discountAmount;
      }

      final now = DateTime.now().toIso8601String();

      // Insert invoice with 'Unpaid' status (no stock deduction yet)
      final invoiceId = await txn.insert('Invoice', {
        'CustomerID': customerId,
        'ShippingAddress': shippingAddress,
        'PaymentMethod': 'Bank Transfer',
        'PaymentStatus': 'Unpaid',
        'TotalAmount': totalAmount,
        'Notes': null,
        'CreatedAt': now,
        'UpdatedAt': null,
      });

      if (invoiceId <= 0) {
        throw StateError('Không thể tạo đơn hàng');
      }

      // Insert invoice details (no stock deduction)
      for (final row in cartItems) {
        final productId = row['ProductID'] as int?;
        final quantity = (row['Quantity'] as int?) ?? 1;
        final unitPrice = (row['UnitPrice'] as num).toDouble();

        if (productId == null) {
          throw StateError('ProductID null khi tạo InvoiceDetail');
        }

        await txn.insert('InvoiceDetail', {
          'InvoiceID': invoiceId,
          'ProductID': productId,
          'PetID': null,
          'Quantity': quantity,
          'UnitPrice': unitPrice,
        });
      }

      // Insert payment record with Pending status
      await txn.insert('Payment', {
        'InvoiceID': invoiceId,
        'Amount': totalAmount,
        'Method': 'Bank Transfer',
        'Status': 'Pending',
        'TransactionCode': null,
        'PaidAt': null,
      });

      // Deduct loyalty points if used
      if (usedPoints > 0) {
        await txn.rawUpdate(
          'UPDATE Customer SET LoyaltyPoints = COALESCE(LoyaltyPoints, 0) - ? WHERE CustomerID = ?',
          [usedPoints, customerId],
        );
      }

      // Clear cart items
      await txn.delete(
        'CartItem',
        where: 'CartID = ? AND ProductID IS NOT NULL',
        whereArgs: [cartId],
      );

      await txn.update(
        'Cart',
        {'UpdatedAt': now},
        where: 'CartID = ?',
        whereArgs: [cartId],
      );

      return invoiceId;
    });
  }

  /// Updates an unpaid order to Paid status after successful payment.
  /// Deducts stock and awards loyalty points.
  Future<void> updateOrderToPaid(int invoiceId, {String? transactionCode}) async {
    final db = await AppDatabase.instance;

    await db.transaction((txn) async {
      // Get invoice info
      final invoiceRows = await txn.query(
        'Invoice',
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      if (invoiceRows.isEmpty) {
        throw StateError('Không tìm thấy đơn hàng');
      }

      final invoice = invoiceRows.first;
      final currentStatus = invoice['PaymentStatus'] as String?;

      if (currentStatus == 'Paid') {
        // Already paid, skip
        return;
      }

      if (currentStatus != 'Unpaid') {
        throw StateError('Đơn hàng không ở trạng thái chờ thanh toán');
      }

      final customerId = invoice['CustomerID'] as int;
      final totalAmount = (invoice['TotalAmount'] as num).toDouble();
      final now = DateTime.now().toIso8601String();

      // Deduct stock for each item
      final detailRows = await txn.query(
        'InvoiceDetail',
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
      );

      for (final detail in detailRows) {
        final productId = detail['ProductID'] as int?;
        final quantity = (detail['Quantity'] as int?) ?? 1;

        if (productId != null) {
          final affected = await txn.rawUpdate(
            'UPDATE Product SET StockQuantity = StockQuantity - ? WHERE ProductID = ? AND StockQuantity >= ?',
            [quantity, productId, quantity],
          );

          if (affected == 0) {
            throw StateError('Không thể cập nhật tồn kho, vui lòng thử lại');
          }
        }
      }

      // Update invoice status to Paid and OrderStatus to Preparing
      await txn.update(
        'Invoice',
        {
          'PaymentStatus': 'Paid',
          'OrderStatus': 'Preparing',
          'UpdatedAt': now,
        },
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
      );

      // Update payment record
      await txn.update(
        'Payment',
        {
          'Status': 'Paid',
          'TransactionCode': transactionCode ?? 'QR-$invoiceId',
          'PaidAt': now,
        },
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
      );

      // Award loyalty points
      final earnedPoints = (totalAmount / 10000).floor();
      if (earnedPoints > 0) {
        await txn.rawUpdate(
          'UPDATE Customer SET LoyaltyPoints = COALESCE(LoyaltyPoints, 0) + ? WHERE CustomerID = ?',
          [earnedPoints, customerId],
        );
      }
    });
  }

  Future<CheckoutResult> checkoutCurrentUser({
    String paymentMethod = 'COD',
    String? shippingAddress,
    String? notes,
    bool useLoyaltyPoints = false,
    String? transactionCode,
  }) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thanh toán');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);

    var invoiceId = 0;
    var totalItems = 0;
    var totalAmount = 0.0;
    var discountAmount = 0.0;
    var usedPoints = 0;
    var earnedPoints = 0;

    try {
      // Diagnostic: print existing tables and schema for Invoice/InvoiceDetail
      try {
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
        print('DB Tables: ${tables.map((r) => r['name']).toList()}');
        final invInfo = await db.rawQuery("PRAGMA table_info('Invoice');");
        print('Invoice schema: $invInfo');
        final detInfo = await db.rawQuery("PRAGMA table_info('InvoiceDetail');");
        print('InvoiceDetail schema: $detInfo');
      } catch (e) {
        print('Failed to read DB schema for diagnostics: $e');
      }

      await db.transaction((txn) async {
      final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

      final cartItems = await txn.rawQuery(
        '''
        SELECT
          ci.CartItemID,
          ci.ProductID,
          ci.Quantity,
          ci.UnitPrice,
          p.ProductName,
          p.StockQuantity
        FROM CartItem ci
        JOIN Product p ON p.ProductID = ci.ProductID
        WHERE ci.CartID = ? AND ci.ProductID IS NOT NULL
        ORDER BY ci.AddedAt DESC, ci.CartItemID DESC
        ''',
        [cartId],
      );

      print('Checkout: cartItems rows count=${cartItems.length}');
      for (final r in cartItems) {
        print('cartItem: $r');
      }

      if (cartItems.isEmpty) {
        throw StateError('Giỏ hàng đang trống');
      }

      // Validate items and compute totals before creating the Invoice
      for (final row in cartItems) {
        if (row['ProductID'] == null) throw StateError('Một mục giỏ hàng thiếu ProductID');
        if (row['Quantity'] == null) throw StateError('Một mục giỏ hàng thiếu Quantity');

        final stock = (row['StockQuantity'] as int?) ?? 0;
        final quantity = (row['Quantity'] as int?) ?? 0;
        final productName = (row['ProductName'] as String?) ?? 'Sản phẩm';

        if (quantity <= 0) {
          throw StateError('Dữ liệu giỏ hàng không hợp lệ');
        }

        if (stock < quantity) {
          throw StateError('Sản phẩm "$productName" không đủ tồn kho');
        }

        final unitPrice = (row['UnitPrice'] as num).toDouble();
        totalItems += quantity;
        totalAmount += (quantity * unitPrice);
      }

      final customerRows = await txn.query(
        'Customer',
        columns: ['LoyaltyPoints'],
        where: 'CustomerID = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      final currentLoyaltyPoints = customerRows.isNotEmpty
          ? ((customerRows.first['LoyaltyPoints'] as int?) ?? 0)
          : 0;

      if (useLoyaltyPoints && currentLoyaltyPoints >= 50) {
        final redeemableBlocks = currentLoyaltyPoints ~/ 50;
        final maxBlocksByAmount = (totalAmount / 5000).floor();
        final blocksToUse = redeemableBlocks > maxBlocksByAmount
            ? maxBlocksByAmount
            : redeemableBlocks;
        usedPoints = blocksToUse * 50;
        discountAmount = blocksToUse * 5000.0;
        totalAmount = totalAmount - discountAmount;
      }

      final now = DateTime.now().toIso8601String();
      final isOnlinePayment = paymentMethod == 'Bank Transfer';
      final invoicePaymentStatus = isOnlinePayment ? 'Paid' : 'Pending';

      // Insert invoice with computed total amount
      invoiceId = await txn.insert('Invoice', {
        'CustomerID': customerId,
        'ShippingAddress': shippingAddress,
        'PaymentMethod': paymentMethod,
        'PaymentStatus': invoicePaymentStatus,
        'TotalAmount': totalAmount,
        'Notes': notes,
        'CreatedAt': now,
        'UpdatedAt': null,
      });

      print('Created Invoice id=$invoiceId totalAmount=$totalAmount totalItems=$totalItems discountAmount=$discountAmount usedPoints=$usedPoints');

      if (invoiceId <= 0) {
        throw StateError('Không thể tạo đơn hàng, invoiceId không hợp lệ');
      }

      // Insert invoice details and decrement stock
      for (final row in cartItems) {
        final productId = row['ProductID'] as int?;
        final quantity = (row['Quantity'] as int?) ?? 1;
        final unitPrice = (row['UnitPrice'] as num).toDouble();

        if (productId == null) {
          throw StateError('ProductID null khi tạo InvoiceDetail');
        }

        await txn.insert('InvoiceDetail', {
          'InvoiceID': invoiceId,
          'ProductID': productId,
          'PetID': null,
          'Quantity': quantity,
          'UnitPrice': unitPrice,
        });

        print('Inserted InvoiceDetail for productId=$productId qty=$quantity');

        final affected = await txn.rawUpdate(
          '''
          UPDATE Product
          SET StockQuantity = StockQuantity - ?
          WHERE ProductID = ? AND StockQuantity >= ?
          ''',
          [quantity, productId, quantity],
        );

        if (affected == 0) {
          throw StateError('Không thể cập nhật tồn kho, vui lòng thử lại');
        }
      }

      await txn.insert('Payment', {
        'InvoiceID': invoiceId,
        'Amount': totalAmount,
        'Method': paymentMethod,
        'Status': isOnlinePayment ? 'Paid' : 'Pending',
        'TransactionCode': isOnlinePayment ? (transactionCode ?? 'QR-$invoiceId') : null,
        'PaidAt': isOnlinePayment ? now : null,
      });

      // Compute and award loyalty points (1 point per 10,000 units)
      try {
        earnedPoints = (totalAmount / 10000).floor();
        if (earnedPoints > 0) {
          await txn.rawUpdate(
            '''
            UPDATE Customer
            SET LoyaltyPoints = COALESCE(LoyaltyPoints, 0) + ?
            WHERE CustomerID = ?
            ''',
            [earnedPoints, customerId],
          );
        }
      } catch (e) {
        print('Failed to award loyalty points: $e');
      }

      if (usedPoints > 0) {
        await txn.rawUpdate(
          '''
          UPDATE Customer
          SET LoyaltyPoints = COALESCE(LoyaltyPoints, 0) - ?
          WHERE CustomerID = ?
          ''',
          [usedPoints, customerId],
        );
      }

      await txn.delete(
        'CartItem',
        where: 'CartID = ? AND ProductID IS NOT NULL',
        whereArgs: [cartId],
      );

      await txn.update(
        'Cart',
        {'UpdatedAt': now},
        where: 'CartID = ?',
        whereArgs: [cartId],
      );
    });
    } catch (e, st) {
      print('checkoutCurrentUser failed: $e');
      print(st.toString());
      // Additional diagnostics
      try {
        final refs = await db.rawQuery("SELECT name, type, sql FROM sqlite_master WHERE sql LIKE '%Invoice_old%';");
        print('sqlite_master refs to Invoice_old: $refs');
      } catch (e2) {
        print('failed to query sqlite_master for Invoice_old: $e2');
      }

      try {
        final triggers = await db.rawQuery("SELECT name, type, sql FROM sqlite_master WHERE type IN ('trigger','view');");
        print('All triggers/views: $triggers');
      } catch (e3) {
        print('failed to list triggers/views: $e3');
      }

      try {
        final fk = await db.rawQuery("PRAGMA foreign_key_list('InvoiceDetail');");
        print('InvoiceDetail foreign keys: $fk');
      } catch (e4) {
        print('failed to get foreign_key_list for InvoiceDetail: $e4');
      }

      rethrow;
    }

    await refreshCountForCurrentUser();

    return CheckoutResult(
      invoiceId: invoiceId,
      totalItems: totalItems,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      usedPoints: usedPoints,
      earnedPoints: earnedPoints,
    );
  }
}

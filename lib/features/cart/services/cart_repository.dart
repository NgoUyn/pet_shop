import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../profile/services/profile_repository.dart';
import '../../notifications/services/notification_repository.dart';
import '../../orders/services/order_firestore_service.dart';
import '../../profile/services/profile_repository.dart';

class CartProductEntry {
  CartProductEntry({
    required this.cartItemId,
    required this.productId,
    required this.petId,
    required this.productName,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.addedAt,
    this.stockQuantity = 0,
  });

  final int cartItemId;
  final int? productId;
  final int? petId;
  final String productName;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final DateTime addedAt;
  final int stockQuantity;

  bool get isPet => petId != null;

  double get lineTotal => unitPrice * quantity;

  static CartProductEntry fromRow(Map<String, Object?> row) {
    return CartProductEntry(
      cartItemId: row['CartItemID'] as int,
      productId: row['ProductID'] as int?,
      petId: row['PetID'] as int?,
      productName: (row['ItemName'] as String?) ?? '',
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
      where: 'CartID = ?',
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

  Future<void> addPetToCart({required int petId}) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thêm vào giỏ hàng');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);

    await db.transaction((txn) async {
      final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

      final petRows = await txn.query(
        'Pet',
        columns: ['Price', 'IsActive'],
        where: 'PetID = ?',
        whereArgs: [petId],
        limit: 1,
      );

      if (petRows.isEmpty) {
        throw StateError('Không tìm thấy thú cưng để thêm vào giỏ hàng');
      }

      final isActive = (petRows.first['IsActive'] as int?) ?? 0;
      if (isActive != 1) {
        throw StateError('Thú cưng hiện không khả dụng');
      }

      final price = (petRows.first['Price'] as num?)?.toDouble();
      if (price == null || price <= 0) {
        throw StateError('Giá thú cưng không hợp lệ');
      }

      final existingRows = await txn.query(
        'CartItem',
        columns: ['CartItemID'],
        where: 'CartID = ? AND PetID = ?',
        whereArgs: [cartId, petId],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        throw StateError('Thú cưng này đã có trong giỏ hàng');
      }

      final now = DateTime.now().toIso8601String();
      await txn.insert('CartItem', {
        'CartID': cartId,
        'ProductID': null,
        'PetID': petId,
        'Quantity': 1,
        'UnitPrice': price,
        'AddedAt': now,
      });

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
        SELECT ci.ProductID, ci.PetID, p.StockQuantity
        FROM CartItem ci
        LEFT JOIN Product p ON ci.ProductID = p.ProductID
        WHERE ci.CartItemID = ?
      ''', [cartItemId]);

      if (itemRows.isEmpty) throw StateError('Không tìm thấy sản phẩm trong giỏ');

      final isPet = itemRows.first['PetID'] != null;
      if (isPet && newQuantity > 1) {
        throw StateError('Thú cưng chỉ có thể mua 1 con');
      }

      if (!isPet) {
        final stock = (itemRows.first['StockQuantity'] as int?) ?? 0;
        if (newQuantity > stock) {
          throw StateError('Số lượng tồn kho không đủ (Hiện có: $stock)');
        }
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
        ci.PetID,
        COALESCE(p.ProductName, pet.PetName) AS ItemName,
        p.ImageURL,
        CASE
          WHEN ci.ProductID IS NOT NULL THEN COALESCE(p.StockQuantity, 0)
          ELSE 1
        END AS StockQuantity,
        ci.UnitPrice,
        ci.Quantity,
        ci.AddedAt
      FROM CartItem ci
      LEFT JOIN Product p ON p.ProductID = ci.ProductID
      LEFT JOIN Pet pet ON pet.PetID = ci.PetID
      WHERE ci.CartID = ?
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
    List<int>? selectedCartItemIds,
  }) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thanh toán');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);
    final firestoreItems = <Map<String, dynamic>>[];
    var totalAmount = 0.0;

    final invoiceId = await db.transaction<int>((txn) async {
      final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

      String selectedWhere = '';
      final selectedArgs = <Object?>[cartId];
      if (selectedCartItemIds != null && selectedCartItemIds.isNotEmpty) {
        selectedWhere = ' AND ci.CartItemID IN (${List.filled(selectedCartItemIds.length, '?').join(',')})';
        selectedArgs.addAll(selectedCartItemIds);
      }

      final cartItems = await txn.rawQuery(
        '''
        SELECT
          ci.CartItemID,
          ci.ProductID,
          ci.PetID,
          ci.Quantity,
          ci.UnitPrice,
          p.ProductName,
          p.StockQuantity,
          pet.PetName
        FROM CartItem ci
        LEFT JOIN Product p ON p.ProductID = ci.ProductID
        LEFT JOIN Pet pet ON pet.PetID = ci.PetID
        WHERE ci.CartID = ?$selectedWhere
        ORDER BY ci.AddedAt DESC, ci.CartItemID DESC
        ''',
        selectedArgs,
      );

      if (cartItems.isEmpty) {
        throw StateError('Giỏ hàng đang trống');
      }

      totalAmount = 0.0;
      var discountAmount = 0.0;
      var usedPoints = 0;

      // Validate items and compute totals
      for (final row in cartItems) {
        if (row['ProductID'] == null && row['PetID'] == null) {
          throw StateError('Một mục giỏ hàng không hợp lệ');
        }
        if (row['Quantity'] == null) throw StateError('Một mục giỏ hàng thiếu Quantity');

        final stock = (row['StockQuantity'] as int?) ?? 0;
        final quantity = (row['Quantity'] as int?) ?? 0;
        final productName = (row['ProductName'] as String?) ?? (row['PetName'] as String?) ?? 'Sản phẩm';
        final isProduct = row['ProductID'] != null;

        if (quantity <= 0) {
          throw StateError('Dữ liệu giỏ hàng không hợp lệ');
        }

        if (isProduct && stock < quantity) {
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
        'OrderStatus': 'Unpaid',
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
        final petId = row['PetID'] as int?;
        final quantity = (row['Quantity'] as int?) ?? 1;
        final unitPrice = (row['UnitPrice'] as num).toDouble();

        if (productId == null && petId == null) {
          throw StateError('Cart item không hợp lệ khi tạo InvoiceDetail');
        }

        await txn.insert('InvoiceDetail', {
          'InvoiceID': invoiceId,
          'ProductID': productId,
          'PetID': petId,
          'Quantity': quantity,
          'UnitPrice': unitPrice,
        });

        firestoreItems.add({
          'invoiceDetailId': 0,
          'productId': productId,
          'productName': row['ProductName'],
          'petId': petId,
          'petName': row['PetName'],
          'quantity': quantity,
          'unitPrice': unitPrice,
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
        where: selectedCartItemIds != null && selectedCartItemIds.isNotEmpty
            ? 'CartID = ? AND CartItemID IN (${List.filled(selectedCartItemIds.length, '?').join(',')})'
            : 'CartID = ?',
        whereArgs: selectedCartItemIds != null && selectedCartItemIds.isNotEmpty
            ? <Object?>[cartId, ...selectedCartItemIds]
            : [cartId],
      );

      await txn.update(
        'Cart',
        {'UpdatedAt': now},
        where: 'CartID = ?',
        whereArgs: [cartId],
      );

      return invoiceId;
    });

    await refreshCountForCurrentUser();

    // Sync order to Firestore
    try {
      final profile = await ProfileRepository.instance.getProfileByUserId(userId);
      final firebaseUser = FirebaseAuth.instance.currentUser;
      await OrderFirestoreService.instance.syncOrderToFirestore(
        invoiceId: invoiceId,
        customerId: customerId,
        customerName: profile?.fullName ?? '',
        customerEmail: profile?.email ?? '',
        customerFirebaseUid: firebaseUser?.uid ?? '',
        paymentStatus: 'Unpaid',
        orderStatus: 'Unpaid',
        totalAmount: totalAmount,
        shippingAddress: shippingAddress,
        paymentMethod: 'Bank Transfer',
        createdAt: DateTime.now().toIso8601String(),
        items: firestoreItems,
      );
    } catch (e) {
      print('createPendingOrder: Firestore sync error (non-fatal): $e');
    }

    try {
      await NotificationRepository.instance.create(
        type: 'order',
        title: 'Đơn hàng chờ thanh toán',
        content: 'Đơn hàng #$invoiceId đã được tạo, vui lòng hoàn tất thanh toán.',
        referenceId: invoiceId,
        referenceType: 'order',
      );
    } catch (_) {}

    return invoiceId;
  }

  /// Updates an unpaid order to Paid status after successful payment.
  /// Deducts stock and awards loyalty points.
  Future<void> updateOrderToPaid(int invoiceId, {String? transactionCode}) async {
    final db = await AppDatabase.instance;
    int? customerUserId;

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

      final customerRows = await txn.rawQuery(
        'SELECT UserID FROM Customer WHERE CustomerID = ? LIMIT 1',
        [customerId],
      );
      customerUserId = customerRows.isNotEmpty ? customerRows.first['UserID'] as int? : null;

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

    // Sync status to Firestore
    await OrderFirestoreService.instance.updateOrderStatusInFirestore(
      invoiceId: invoiceId,
      orderStatus: 'Preparing',
      paymentStatus: 'Paid',
    );

    if (customerUserId != null) {
      try {
        await NotificationRepository.instance.create(
          userId: customerUserId,
          type: 'order',
          title: 'Đơn hàng đang chuẩn bị',
          content: 'Đơn hàng #$invoiceId đã thanh toán thành công và đang được chuẩn bị.',
          referenceId: invoiceId,
          referenceType: 'order',
        );
      } catch (_) {}
    }
  }

  Future<CheckoutResult> checkoutCurrentUser({
    String paymentMethod = 'COD',
    String? shippingAddress,
    String? notes,
    bool useLoyaltyPoints = false,
    String? transactionCode,
    List<int>? selectedCartItemIds,
  }) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Vui lòng đăng nhập để thanh toán');
    }

    final profile = await ProfileRepository.instance.getCurrentProfile();
    final profilePhone = profile?.phone?.trim() ?? '';
    final profileAddress = profile?.address?.trim() ?? '';
    final resolvedShippingAddress = shippingAddress?.trim().isNotEmpty == true
        ? shippingAddress!.trim()
        : profileAddress;

    if (profile == null || profilePhone.isEmpty || profileAddress.isEmpty || resolvedShippingAddress.isEmpty) {
      throw StateError('Vui lòng cập nhật đầy đủ thông tin hồ sơ trước khi mua hàng');
    }

    final db = await AppDatabase.instance;
    final customerId = await _resolveCustomerId(userId);

    var invoiceId = 0;
    var totalItems = 0;
    var totalAmount = 0.0;
    var discountAmount = 0.0;
    var usedPoints = 0;
    var earnedPoints = 0;
    final firestoreItems = <Map<String, dynamic>>[];

    try {
      await db.transaction((txn) async {
        final cartId = await _ensureCartIdForCustomer(customerId, txnOrDb: txn);

        String selectedWhere = '';
        final selectedArgs = <Object?>[cartId];
        if (selectedCartItemIds != null && selectedCartItemIds.isNotEmpty) {
          selectedWhere = ' AND ci.CartItemID IN (${List.filled(selectedCartItemIds.length, '?').join(',')})';
          selectedArgs.addAll(selectedCartItemIds);
        }

        final cartItems = await txn.rawQuery(
          '''
          SELECT
            ci.CartItemID,
            ci.ProductID,
            ci.PetID,
            ci.Quantity,
            ci.UnitPrice,
            p.ProductName,
            p.StockQuantity,
            pet.PetName
          FROM CartItem ci
          LEFT JOIN Product p ON p.ProductID = ci.ProductID
          LEFT JOIN Pet pet ON pet.PetID = ci.PetID
          WHERE ci.CartID = ?$selectedWhere
          ORDER BY ci.AddedAt DESC, ci.CartItemID DESC
          ''',
          selectedArgs,
        );

        if (cartItems.isEmpty) {
          throw StateError('Giỏ hàng đang trống');
        }

        // Validate items and compute totals before creating the Invoice
        for (final row in cartItems) {
          if (row['ProductID'] == null && row['PetID'] == null) {
            throw StateError('Một mục giỏ hàng không hợp lệ');
          }
          if (row['Quantity'] == null) throw StateError('Một mục giỏ hàng thiếu Quantity');

          final stock = (row['StockQuantity'] as int?) ?? 0;
          final quantity = (row['Quantity'] as int?) ?? 0;
          final productName = (row['ProductName'] as String?) ?? (row['PetName'] as String?) ?? 'Sản phẩm';
          final isProduct = row['ProductID'] != null;

          if (quantity <= 0) {
            throw StateError('Dữ liệu giỏ hàng không hợp lệ');
          }

          if (isProduct && stock < quantity) {
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
          'ShippingAddress': resolvedShippingAddress,
          'PaymentMethod': paymentMethod,
          'PaymentStatus': invoicePaymentStatus,
          'OrderStatus': 'Preparing',
          'TotalAmount': totalAmount,
          'Notes': notes,
          'CreatedAt': now,
          'UpdatedAt': null,
        });

        if (invoiceId <= 0) {
          throw StateError('Không thể tạo đơn hàng, invoiceId không hợp lệ');
        }

        // Insert invoice details and decrement stock
        for (final row in cartItems) {
          final productId = row['ProductID'] as int?;
          final petId = row['PetID'] as int?;
          final quantity = (row['Quantity'] as int?) ?? 1;
          final unitPrice = (row['UnitPrice'] as num).toDouble();

          if (productId == null && petId == null) {
            throw StateError('Cart item không hợp lệ khi tạo InvoiceDetail');
          }

          await txn.insert('InvoiceDetail', {
            'InvoiceID': invoiceId,
            'ProductID': productId,
            'PetID': petId,
            'Quantity': quantity,
            'UnitPrice': unitPrice,
          });

          if (productId != null) {
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

          firestoreItems.add({
            'invoiceDetailId': 0,
            'productId': productId,
            'productName': row['ProductName'],
            'petId': petId,
            'petName': row['PetName'],
            'quantity': quantity,
            'unitPrice': unitPrice,
          });
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
          // ignore
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
          where: selectedCartItemIds != null && selectedCartItemIds.isNotEmpty
              ? 'CartID = ? AND CartItemID IN (${List.filled(selectedCartItemIds.length, '?').join(',')})'
              : 'CartID = ?',
          whereArgs: selectedCartItemIds != null && selectedCartItemIds.isNotEmpty
              ? <Object?>[cartId, ...selectedCartItemIds]
              : [cartId],
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
      rethrow;
    }

    await refreshCountForCurrentUser();

    // Sync order to Firestore
    try {
      final profile = await ProfileRepository.instance.getProfileByUserId(userId);
      final firebaseUser = FirebaseAuth.instance.currentUser;
      await OrderFirestoreService.instance.syncOrderToFirestore(
        invoiceId: invoiceId,
        customerId: customerId,
        customerName: profile?.fullName ?? '',
        customerEmail: profile?.email ?? '',
        customerFirebaseUid: firebaseUser?.uid ?? '',
        paymentStatus: paymentMethod == 'Bank Transfer' ? 'Paid' : 'Pending',
        orderStatus: 'Preparing',
        totalAmount: totalAmount,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now().toIso8601String(),
        items: firestoreItems,
      );
    } catch (e) {
      print('checkoutCurrentUser: Firestore sync error (non-fatal): $e');
    }

    // Create notification for the user
    try {
      final isOnlinePayment = paymentMethod == 'Bank Transfer';
      final statusText = isOnlinePayment ? 'đang được chuẩn bị' : 'đã được tiếp nhận và đang chuẩn bị';
      await NotificationRepository.instance.create(
        type: 'order',
        title: 'Đơn hàng đang chuẩn bị',
        content: 'Đơn hàng #$invoiceId $statusText.',
        referenceId: invoiceId,
        referenceType: 'order',
      );
    } catch (_) {}

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

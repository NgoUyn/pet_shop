import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../notifications/services/notification_repository.dart';
import 'order_firestore_service.dart';

class OrderInfo {
  final int invoiceId;
  final String paymentStatus;
  final String orderStatus;
  final double totalAmount;
  final String? shippingAddress;
  final String? paymentMethod;
  final String createdAt;
  final String? updatedAt;
  final List<OrderItemInfo> items;
  final String? customerName;

  OrderInfo({
    required this.invoiceId,
    required this.paymentStatus,
    required this.orderStatus,
    required this.totalAmount,
    this.shippingAddress,
    this.paymentMethod,
    required this.createdAt,
    this.updatedAt,
    required this.items,
    this.customerName,
  });

  String get statusLabel {
    switch (orderStatus) {
      case 'Unpaid':
        return 'Chưa thanh toán';
      case 'Preparing':
        return 'Đang chuẩn bị';
      case 'Shipping':
        return 'Đang vận chuyển';
      case 'Completed':
        return 'Hoàn thành';
      case 'Cancelled':
        return 'Đã hủy';
      default:
        return paymentStatus;
    }
  }

  static OrderInfo fromRow(Map<String, Object?> row, List<OrderItemInfo> items) {
    return OrderInfo(
      invoiceId: row['InvoiceID'] as int,
      paymentStatus: (row['PaymentStatus'] as String?) ?? '',
      orderStatus: (row['OrderStatus'] as String?) ?? (row['PaymentStatus'] as String?) ?? '',
      totalAmount: (row['TotalAmount'] as num).toDouble(),
      shippingAddress: row['ShippingAddress'] as String?,
      paymentMethod: row['PaymentMethod'] as String?,
      createdAt: (row['CreatedAt'] as String?) ?? '',
      updatedAt: row['UpdatedAt'] as String?,
      items: items,
      customerName: row['CustomerName'] as String?,
    );
  }

  static OrderInfo fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final itemsList = (data['items'] as List<dynamic>?) ?? [];
    final items = itemsList.map((item) {
      final map = Map<String, Object?>.from(item as Map);
      return OrderItemInfo(
        invoiceDetailId: (map['invoiceDetailId'] as num?)?.toInt() ?? 0,
        productId: (map['productId'] as num?)?.toInt(),
        productName: map['productName'] as String?,
        petId: (map['petId'] as num?)?.toInt(),
        petName: map['petName'] as String?,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    return OrderInfo(
      invoiceId: (data['invoiceId'] as num?)?.toInt() ?? 0,
      paymentStatus: (data['paymentStatus'] as String?) ?? '',
      orderStatus: (data['orderStatus'] as String?) ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      shippingAddress: data['shippingAddress'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      createdAt: (data['createdAt'] as String?) ?? '',
      updatedAt: data['updatedAt'] as String?,
      items: items,
      customerName: data['customerName'] as String?,
    );
  }
}

class OrderItemInfo {
  final int invoiceDetailId;
  final int? productId;
  final String? productName;
  final int? petId;
  final String? petName;
  final int quantity;
  final double unitPrice;

  OrderItemInfo({
    required this.invoiceDetailId,
    this.productId,
    this.productName,
    this.petId,
    this.petName,
    required this.quantity,
    required this.unitPrice,
  });

  String get displayName => petName ?? productName ?? 'Sản phẩm';

  static OrderItemInfo fromRow(Map<String, Object?> row) {
    return OrderItemInfo(
      invoiceDetailId: row['InvoiceDetailID'] as int,
      productId: row['ProductID'] as int?,
      productName: row['ProductName'] as String?,
      petId: row['PetID'] as int?,
      petName: row['PetName'] as String?,
      quantity: (row['Quantity'] as int?) ?? 1,
      unitPrice: (row['UnitPrice'] as num).toDouble(),
    );
  }
}

class OrderRepository {
  OrderRepository._();

  static final OrderRepository instance = OrderRepository._();

  /// Get all orders for the current user
  Future<List<OrderInfo>> getOrdersForCurrentUser({String? statusFilter}) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

    final db = await AppDatabase.instance;

    // Get customer ID
    final customerRows = await db.query(
      'Customer',
      columns: ['CustomerID'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (customerRows.isEmpty) return [];
    final customerId = customerRows.first['CustomerID'] as int;

    // Build query
    String where = 'i.CustomerID = ?';
    List<dynamic> whereArgs = [customerId];

    if (statusFilter != null && statusFilter.isNotEmpty) {
      where += ' AND (i.OrderStatus = ? OR (i.OrderStatus IS NULL AND i.PaymentStatus = ?))';
      whereArgs.add(statusFilter);
      whereArgs.add(statusFilter);
    }

    final invoiceRows = await db.rawQuery(
      '''
      SELECT i.*,
        COALESCE(i.OrderStatus, i.PaymentStatus) as EffectiveStatus
      FROM Invoice i
      WHERE $where
      ORDER BY i.CreatedAt DESC
      ''',
      whereArgs,
    );

    final orders = <OrderInfo>[];
    for (final row in invoiceRows) {
      final invoiceId = row['InvoiceID'] as int;

      final detailRows = await db.rawQuery(
        '''
        SELECT id.*, p.ProductName, pet.PetName
        FROM InvoiceDetail id
        LEFT JOIN Product p ON id.ProductID = p.ProductID
        LEFT JOIN Pet pet ON id.PetID = pet.PetID
        WHERE id.InvoiceID = ?
        ''',
        [invoiceId],
      );

      final items = detailRows.map(OrderItemInfo.fromRow).toList();
      orders.add(OrderInfo.fromRow(row, items));
    }

    // Merge with Firestore orders (cross-device)
    try {
      final firestoreOrders = await OrderFirestoreService.instance
          .getOrdersForCurrentFirebaseUser(statusFilter: statusFilter);
      final localInvoiceIds = orders.map((o) => o.invoiceId).toSet();
      for (final fo in firestoreOrders) {
        if (!localInvoiceIds.contains(fo.invoiceId)) {
          orders.add(fo);
        }
      }
    } catch (_) {}

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Get all orders (for admin)
  Future<List<OrderInfo>> getAllOrders({String? statusFilter}) async {
    final db = await AppDatabase.instance;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (statusFilter != null && statusFilter.isNotEmpty) {
      where += ' AND (i.OrderStatus = ? OR (i.OrderStatus IS NULL AND i.PaymentStatus = ?))';
      whereArgs.add(statusFilter);
      whereArgs.add(statusFilter);
    }

    final invoiceRows = await db.rawQuery(
      '''
      SELECT i.*,
        COALESCE(i.OrderStatus, i.PaymentStatus) as EffectiveStatus,
        c.UserID,
        u.FullName as CustomerName
      FROM Invoice i
      JOIN Customer c ON i.CustomerID = c.CustomerID
      JOIN User u ON c.UserID = u.UserID
      WHERE $where
      ORDER BY i.CreatedAt DESC
      ''',
      whereArgs,
    );

    final orders = <OrderInfo>[];
    for (final row in invoiceRows) {
      final invoiceId = row['InvoiceID'] as int;

      final detailRows = await db.rawQuery(
        '''
        SELECT id.*, p.ProductName, pet.PetName
        FROM InvoiceDetail id
        LEFT JOIN Product p ON id.ProductID = p.ProductID
        LEFT JOIN Pet pet ON id.PetID = pet.PetID
        WHERE id.InvoiceID = ?
        ''',
        [invoiceId],
      );

      final items = detailRows.map(OrderItemInfo.fromRow).toList();
      orders.add(OrderInfo.fromRow(row, items));
    }

    // Merge with Firestore orders (cross-device)
    try {
      final firestoreOrders = await OrderFirestoreService.instance
          .getOrdersForCurrentFirebaseUser(statusFilter: statusFilter);
      final localInvoiceIds = orders.map((o) => o.invoiceId).toSet();
      for (final fo in firestoreOrders) {
        if (!localInvoiceIds.contains(fo.invoiceId)) {
          orders.add(fo);
        }
      }
    } catch (_) {}

    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Get customer UserID from invoice
  Future<int?> _getCustomerUserId(int invoiceId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      '''
      SELECT c.UserID FROM Invoice i
      JOIN Customer c ON i.CustomerID = c.CustomerID
      WHERE i.InvoiceID = ?
      ''',
      [invoiceId],
    );
    if (rows.isEmpty) return null;
    return rows.first['UserID'] as int?;
  }

  /// Admin: Update order status from Preparing to Shipping
  Future<void> confirmPreparing(int invoiceId) async {
    // 1. Validate and update via Firestore (shared source of truth)
    final doc = await _getOrderDoc(invoiceId);
    final currentStatus = (doc['orderStatus'] as String?) ?? '';
    if (currentStatus != 'Preparing') {
      throw StateError('Không thể cập nhật trạng thái. Đơn hàng không ở trạng thái "Đang chuẩn bị".');
    }

    await OrderFirestoreService.instance.updateOrderStatusInFirestore(
      invoiceId: invoiceId,
      orderStatus: 'Shipping',
    );

    // 2. Try local SQLite (may not exist on admin device)
    await _tryUpdateLocalStatus(invoiceId, 'Shipping');

    // 3. Notify customer via Firestore
    await _notifyCustomer(doc, invoiceId, 'order',
        'Đơn hàng đang được giao',
        'Đơn hàng #$invoiceId đã được chuyển sang trạng thái đang vận chuyển.');
  }

  /// Admin: Mark order as Completed
  Future<void> markCompleted(int invoiceId) async {
    // 1. Validate and update via Firestore (shared source of truth)
    final doc = await _getOrderDoc(invoiceId);
    final currentStatus = (doc['orderStatus'] as String?) ?? '';
    if (currentStatus != 'Shipping') {
      throw StateError('Không thể cập nhật trạng thái. Đơn hàng không ở trạng thái "Đang vận chuyển".');
    }

    await OrderFirestoreService.instance.updateOrderStatusInFirestore(
      invoiceId: invoiceId,
      orderStatus: 'Completed',
    );

    // 2. Try local SQLite (may not exist on admin device)
    await _tryUpdateLocalStatus(invoiceId, 'Completed');

    // 3. Notify customer via Firestore
    await _notifyCustomer(doc, invoiceId, 'order',
        'Đơn hàng đã hoàn thành',
        'Đơn hàng #$invoiceId đã được giao thành công. Cảm ơn bạn đã mua hàng!');
  }

  /// Admin: Cancel order
  Future<void> cancelOrder(int invoiceId) async {
    // 1. Validate and update via Firestore (shared source of truth)
    final doc = await _getOrderDoc(invoiceId);
    final currentStatus = (doc['orderStatus'] as String?) ?? '';
    if (currentStatus == 'Completed' || currentStatus == 'Cancelled') {
      throw StateError('Không thể hủy đơn hàng ở trạng thái "$currentStatus".');
    }

    await OrderFirestoreService.instance.updateOrderStatusInFirestore(
      invoiceId: invoiceId,
      orderStatus: 'Cancelled',
      paymentStatus: 'Cancelled',
    );

    // 2. Try local SQLite: mark invoice/payment cancelled and restore product stock
    try {
      final db = await AppDatabase.instance;
      await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();

        await txn.update(
          'Invoice',
          {
            'PaymentStatus': 'Cancelled',
            'OrderStatus': 'Cancelled',
            'UpdatedAt': now,
          },
          where: 'InvoiceID = ?',
          whereArgs: [invoiceId],
        );

        // Update payment record status if exists
        try {
          await txn.update(
            'Payment',
            {'Status': 'Cancelled'},
            where: 'InvoiceID = ?',
            whereArgs: [invoiceId],
          );
        } catch (_) {}

        // Restore stock for each product/pet in the invoice
        final details = await txn.query(
          'InvoiceDetail',
          columns: ['ProductID', 'PetID', 'Quantity'],
          where: 'InvoiceID = ?',
          whereArgs: [invoiceId],
        );

        for (final detail in details) {
          final productId = detail['ProductID'] as int?;
          final petId = detail['PetID'] as int?;
          final quantity = (detail['Quantity'] as int?) ?? 0;
          if (productId != null && quantity > 0) {
            await txn.rawUpdate(
              'UPDATE Product SET StockQuantity = StockQuantity + ? WHERE ProductID = ?',
              [quantity, productId],
            );
          }
          if (petId != null && quantity > 0) {
            await txn.rawUpdate(
              'UPDATE Pet SET StockQuantity = StockQuantity + ? WHERE PetID = ?',
              [quantity, petId],
            );
          }
        }
      });
    } catch (e) {
      print('cancelOrder local restore error: $e');
      // Fallback: best-effort local status update
      await _tryUpdateLocalStatus(invoiceId, 'Cancelled');
    }

    // 3. Notify customer via Firestore
    await _notifyCustomer(doc, invoiceId, 'order',
        'Đơn hàng đã bị hủy',
        'Đơn hàng #$invoiceId đã bị hủy.');
  }

  /// Read a single order doc from Firestore, throw if not found
  Future<Map<String, dynamic>> _getOrderDoc(int invoiceId) async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(invoiceId.toString())
        .get();
    if (!doc.exists) {
      throw StateError('Không tìm thấy đơn hàng #$invoiceId');
    }
    return doc.data()!;
  }

  /// Best-effort update to local SQLite (order may not exist on admin device)
  Future<void> _tryUpdateLocalStatus(int invoiceId, String orderStatus) async {
    try {
      final db = await AppDatabase.instance;
      await db.update(
        'Invoice',
        {
          'OrderStatus': orderStatus,
          'UpdatedAt': DateTime.now().toIso8601String(),
        },
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
      );
    } catch (_) {}
  }

  /// Write a notification to Firestore so the customer can see it cross-device
  Future<void> _notifyCustomer(
    Map<String, dynamic> orderDoc,
    int invoiceId,
    String type,
    String title,
    String content,
  ) async {
    final customerFirebaseUid = (orderDoc['customerFirebaseUid'] as String?) ?? '';
    if (customerFirebaseUid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'firebaseUid': customerFirebaseUid,
        'type': type,
        'title': title,
        'content': content,
        'referenceId': invoiceId,
        'referenceType': 'order',
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
      });

      // Also try local notification if the customer user exists locally
      final localUserId = await _getCustomerUserId(invoiceId);
      if (localUserId != null) {
        await NotificationRepository.instance.create(
          userId: localUserId,
          type: type,
          title: title,
          content: content,
          referenceId: invoiceId,
          referenceType: 'order',
        );
      }
    } catch (_) {}
  }
}

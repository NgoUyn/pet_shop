import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../notifications/services/notification_repository.dart';

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
    );
  }
}

class OrderItemInfo {
  final int invoiceDetailId;
  final int? productId;
  final String? productName;
  final int quantity;
  final double unitPrice;

  OrderItemInfo({
    required this.invoiceDetailId,
    this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  static OrderItemInfo fromRow(Map<String, Object?> row) {
    return OrderItemInfo(
      invoiceDetailId: row['InvoiceDetailID'] as int,
      productId: row['ProductID'] as int?,
      productName: row['ProductName'] as String?,
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
        SELECT id.*, p.ProductName
        FROM InvoiceDetail id
        LEFT JOIN Product p ON id.ProductID = p.ProductID
        WHERE id.InvoiceID = ?
        ''',
        [invoiceId],
      );

      final items = detailRows.map(OrderItemInfo.fromRow).toList();
      orders.add(OrderInfo.fromRow(row, items));
    }

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
        SELECT id.*, p.ProductName
        FROM InvoiceDetail id
        LEFT JOIN Product p ON id.ProductID = p.ProductID
        WHERE id.InvoiceID = ?
        ''',
        [invoiceId],
      );

      final items = detailRows.map(OrderItemInfo.fromRow).toList();
      orders.add(OrderInfo.fromRow(row, items));
    }

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
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    final affected = await db.update(
      'Invoice',
      {
        'OrderStatus': 'Shipping',
        'UpdatedAt': now,
      },
      where: 'InvoiceID = ? AND OrderStatus = ?',
      whereArgs: [invoiceId, 'Preparing'],
    );

    if (affected == 0) {
      throw StateError('Không thể cập nhật trạng thái. Đơn hàng không ở trạng thái "Đang chuẩn bị".');
    }

    // Create notification for customer
    final customerUserId = await _getCustomerUserId(invoiceId);
    if (customerUserId != null) {
      try {
        await NotificationRepository.instance.create(
          userId: customerUserId,
          type: 'order',
          title: 'Đơn hàng đang được giao',
          content: 'Đơn hàng #$invoiceId đã được chuyển sang trạng thái đang vận chuyển.',
          referenceId: invoiceId,
          referenceType: 'order',
        );
      } catch (_) {}
    }
  }

  /// Admin: Mark order as Completed
  Future<void> markCompleted(int invoiceId) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    final affected = await db.update(
      'Invoice',
      {
        'OrderStatus': 'Completed',
        'UpdatedAt': now,
      },
      where: 'InvoiceID = ? AND OrderStatus = ?',
      whereArgs: [invoiceId, 'Shipping'],
    );

    if (affected == 0) {
      throw StateError('Không thể cập nhật trạng thái. Đơn hàng không ở trạng thái "Đang vận chuyển".');
    }

    // Create notification for customer
    final customerUserId = await _getCustomerUserId(invoiceId);
    if (customerUserId != null) {
      try {
        await NotificationRepository.instance.create(
          userId: customerUserId,
          type: 'order',
          title: 'Đơn hàng đã hoàn thành',
          content: 'Đơn hàng #$invoiceId đã được giao thành công. Cảm ơn bạn đã mua hàng!',
          referenceId: invoiceId,
          referenceType: 'order',
        );
      } catch (_) {}
    }
  }

  /// Admin: Cancel order
  Future<void> cancelOrder(int invoiceId) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'Invoice',
      {
        'OrderStatus': 'Cancelled',
        'PaymentStatus': 'Cancelled',
        'UpdatedAt': now,
      },
      where: 'InvoiceID = ? AND OrderStatus NOT IN (?, ?)',
      whereArgs: [invoiceId, 'Completed', 'Cancelled'],
    );

    // Create notification for customer
    final customerUserId = await _getCustomerUserId(invoiceId);
    if (customerUserId != null) {
      try {
        await NotificationRepository.instance.create(
          userId: customerUserId,
          type: 'order',
          title: 'Đơn hàng đã bị hủy',
          content: 'Đơn hàng #$invoiceId đã bị hủy.',
          referenceId: invoiceId,
          referenceType: 'order',
        );
      } catch (_) {}
    }
  }
}

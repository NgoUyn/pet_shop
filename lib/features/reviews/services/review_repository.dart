import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';
import '../../orders/services/order_firestore_service.dart';

class ReviewItem {
  ReviewItem({
    required this.reviewId,
    required this.invoiceId,
    required this.userId,
    required this.rating,
    this.content,
    required this.createdAt,
    this.updatedAt,
  });

  final int reviewId;
  final int invoiceId;
  final int userId;
  final int rating;
  final String? content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  static ReviewItem fromRow(Map<String, Object?> row) {
    final createdAtRaw = row['CreatedAt'] as String;
    final updatedAtRaw = row['UpdatedAt'] as String?;
    return ReviewItem(
      reviewId: row['ReviewID'] as int,
      invoiceId: row['InvoiceID'] as int,
      userId: row['UserID'] as int,
      rating: row['Rating'] as int,
      content: row['Content'] as String?,
      createdAt: DateTime.parse(createdAtRaw),
      updatedAt: updatedAtRaw == null ? null : DateTime.parse(updatedAtRaw),
    );
  }
}

class ReviewRepository {
  ReviewRepository._();
  static final ReviewRepository instance = ReviewRepository._();

  Future<int> create({
    required int invoiceId,
    int? userId,
    required int rating,
    String? content,
  }) async {
    final db = await AppDatabase.instance;
    final resolvedUserId = userId ?? AuthSession.instance.currentUserId.value;
    if (resolvedUserId == null) {
      throw StateError('Không tìm thấy user để tạo đánh giá');
    }
    if (rating < 1 || rating > 5) {
      throw StateError('Đánh giá phải từ 1 đến 5 sao');
    }

    // Ensure invoice exists locally (may have been created on another device)
    await _ensureInvoiceExistsLocally(db, invoiceId);

    final now = DateTime.now().toIso8601String();
    return db.insert('Review', {
      'InvoiceID': invoiceId,
      'UserID': resolvedUserId,
      'Rating': rating,
      'Content': content?.trim().isEmpty == true ? null : content?.trim(),
      'CreatedAt': now,
      'UpdatedAt': null,
    });
  }

  Future<void> _ensureInvoiceExistsLocally(Database db, int invoiceId) async {
    final rows = await db.query(
      'Invoice',
      columns: ['InvoiceID'],
      where: 'InvoiceID = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (rows.isNotEmpty) return; // Already exists locally

    // Try to sync from Firestore
    try {
      final doc = await OrderFirestoreService.instance.getOrderDoc(invoiceId);
      if (doc == null) return;

      // Resolve local CustomerID from current user (may differ from original device)
      final localCustomerId = await _resolveLocalCustomerId(db);
      if (localCustomerId == null) return;

      final totalAmount = (doc['totalAmount'] as num?)?.toDouble() ?? 0;
      final paymentMethod = (doc['paymentMethod'] as String?) ?? '';
      final paymentStatus = (doc['paymentStatus'] as String?) ?? '';
      final orderStatus = (doc['orderStatus'] as String?) ?? '';
      final shippingAddress = doc['shippingAddress'] as String?;
      final createdAt = (doc['createdAt'] as String?) ?? DateTime.now().toIso8601String();
      final updatedAt = doc['updatedAt'] as String?;

      await db.insert('Invoice', {
        'InvoiceID': invoiceId,
        'CustomerID': localCustomerId,
        'ShippingAddress': shippingAddress,
        'PaymentMethod': paymentMethod,
        'PaymentStatus': paymentStatus,
        'OrderStatus': orderStatus,
        'TotalAmount': totalAmount,
        'CreatedAt': createdAt,
        'UpdatedAt': updatedAt,
      });
    } catch (e) {
      print('ReviewRepository._ensureInvoiceExistsLocally: $e');
    }
  }

  Future<int?> _resolveLocalCustomerId(Database db) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return null;
    final rows = await db.query(
      'Customer',
      columns: ['CustomerID'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty ? (rows.first['CustomerID'] as int?) : null;
  }

  Future<ReviewItem?> getByInvoiceId(int invoiceId) async {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) return null;

    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Review',
      where: 'InvoiceID = ? AND UserID = ?',
      whereArgs: [invoiceId, currentUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReviewItem.fromRow(rows.first);
  }

  Future<bool> hasReviewed(int invoiceId) async {
    final review = await getByInvoiceId(invoiceId);
    return review != null;
  }
}

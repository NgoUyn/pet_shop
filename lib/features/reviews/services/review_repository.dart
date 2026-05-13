import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    this.customerName,
    this.imageUrls = const [],
    this.firestoreDocId,
    this.isFlagged = false,
    this.moderationStatus,
  });

  final int reviewId;
  final int invoiceId;
  final int userId;
  final int rating;
  final String? content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? customerName;
  final List<String> imageUrls;
  final String? firestoreDocId;
  final bool isFlagged;
  final String? moderationStatus;

  static ReviewItem fromRow(Map<String, Object?> row, {List<String>? imageUrls}) {
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
      customerName: row['CustomerName'] as String?,
      imageUrls: imageUrls ?? [],
      isFlagged: row['IsFlagged'] is int ? (row['IsFlagged'] as int) == 1 : false,
      moderationStatus: row['ModerationStatus'] as String?,
    );
  }

  static ReviewItem fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdAtStr = (data['createdAt'] as String?) ?? DateTime.now().toIso8601String();
    final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
    final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    return ReviewItem(
      reviewId: (data['reviewId'] as num?)?.toInt() ?? 0,
      invoiceId: (data['invoiceId'] as num?)?.toInt() ?? 0,
      userId: 0,
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      content: data['content'] as String?,
      createdAt: createdAt,
      customerName: data['customerName'] as String?,
      imageUrls: imageUrls,
      firestoreDocId: doc.id,
      isFlagged: data['isFlagged'] as bool? ?? false,
      moderationStatus: data['moderationStatus'] as String?,
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
    List<String>? imageUrls,
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
    final reviewId = await db.insert('Review', {
      'InvoiceID': invoiceId,
      'UserID': resolvedUserId,
      'Rating': rating,
      'Content': content?.trim().isEmpty == true ? null : content?.trim(),
      'CreatedAt': now,
      'UpdatedAt': null,
    });

    // Insert review images
    if (imageUrls != null && imageUrls.isNotEmpty) {
      for (var i = 0; i < imageUrls.length; i++) {
        await db.insert('ReviewImage', {
          'ReviewID': reviewId,
          'ImageUrl': imageUrls[i],
          'SortOrder': i,
        });
      }
    }

    // Sync to Firestore for cross-device access
    _syncReviewToFirestore(
      reviewId: reviewId,
      invoiceId: invoiceId,
      resolvedUserId: resolvedUserId,
      rating: rating,
      content: content,
      imageUrls: imageUrls,
      now: now,
    );

    return reviewId;
  }

  void _syncReviewToFirestore({
    required int reviewId,
    required int invoiceId,
    required int resolvedUserId,
    required int rating,
    String? content,
    List<String>? imageUrls,
    required String now,
  }) {
    // Fire-and-forget: don't block the user
    _doSyncToFirestore(
      reviewId: reviewId,
      invoiceId: invoiceId,
      resolvedUserId: resolvedUserId,
      rating: rating,
      content: content,
      imageUrls: imageUrls,
      now: now,
    );
  }

  Future<void> _doSyncToFirestore({
    required int reviewId,
    required int invoiceId,
    required int resolvedUserId,
    required int rating,
    String? content,
    List<String>? imageUrls,
    required String now,
  }) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final db = await AppDatabase.instance;

      // Get customer name
      String? customerName;
      try {
        final userRows = await db.query('User',
          columns: ['FullName'],
          where: 'UserID = ?',
          whereArgs: [resolvedUserId],
          limit: 1,
        );
        customerName = userRows.isNotEmpty ? (userRows.first['FullName'] as String?) : null;
      } catch (_) {}

      // Get product IDs for this invoice (for querying by product)
      final detailRows = await db.query('InvoiceDetail',
        columns: ['ProductID'],
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
      );
      final productIds = detailRows
          .map((r) => r['ProductID'] as int?)
          .where((id) => id != null)
          .map((id) => id!)
          .toList();

      await FirebaseFirestore.instance.collection('reviews').add({
        'reviewId': reviewId,
        'invoiceId': invoiceId,
        'firebaseUid': firebaseUser?.uid ?? '',
        'customerName': customerName ?? '',
        'rating': rating,
        'content': content?.trim().isEmpty == true ? null : content?.trim(),
        'imageUrls': imageUrls ?? [],
        'productIds': productIds,
        'createdAt': now,
        'moderationStatus': 'pending',
        'isFlagged': false,
      });
    } catch (e) {
      print('ReviewRepository._doSyncToFirestore: $e');
    }
  }

  Future<void> _ensureInvoiceExistsLocally(Database db, int invoiceId) async {
    final invoiceRows = await db.query(
      'Invoice',
      columns: ['InvoiceID'],
      where: 'InvoiceID = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (invoiceRows.isNotEmpty) {
      // Invoice exists — ensure details also exist (may be missing from older sync)
      final detailRows = await db.query(
        'InvoiceDetail',
        columns: ['InvoiceDetailID'],
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (detailRows.isNotEmpty) return; // Both invoice and details exist
      // Fall through to sync details from Firestore
    }

    // Try to sync from Firestore
    try {
      final doc = await OrderFirestoreService.instance.getOrderDoc(invoiceId);
      if (doc == null) return;

      // Resolve local CustomerID from current user (may differ from original device)
      final localCustomerId = await _resolveLocalCustomerId(db);
      if (localCustomerId == null) return;

      if (invoiceRows.isEmpty) {
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
      }

      // Sync InvoiceDetail rows so product JOIN queries work
      // Skip if they already exist
      final existingDetails = await db.query(
        'InvoiceDetail',
        columns: ['InvoiceDetailID'],
        where: 'InvoiceID = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (existingDetails.isNotEmpty) return;

      final items = (doc['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        final itemMap = Map<String, Object?>.from(item as Map);
        final productId = (itemMap['productId'] as num?)?.toInt();
        final petId = (itemMap['petId'] as num?)?.toInt();
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 1;
        final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
        await db.insert('InvoiceDetail', {
          'InvoiceID': invoiceId,
          'ProductID': productId,
          'PetID': petId,
          'Quantity': quantity,
          'UnitPrice': unitPrice,
        });
      }
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
    final reviewId = rows.first['ReviewID'] as int;
    final images = await _loadImages(db, reviewId);
    return ReviewItem.fromRow(rows.first, imageUrls: images);
  }

  Future<bool> hasReviewed(int invoiceId) async {
    final review = await getByInvoiceId(invoiceId);
    return review != null;
  }

  /// Get all reviews for a specific product (local + Firestore)
  Future<List<ReviewItem>> getByProductId(int productId) async {
    final results = await Future.wait([
      _getLocalByProductId(productId),
      _getFirestoreByProductId(productId),
    ]);

    final localItems = results[0];
    final firestoreItems = results[1];

    // Merge: dedup by (invoiceId, customerName) — Firestore takes precedence
    // so moderationStatus from Cloud Function is preserved
    final map = <String, ReviewItem>{};
    for (final item in localItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      map[key] = item;
    }
    for (final item in firestoreItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      map[key] = item; // Overwrite local with Firestore (has moderation data)
    }
    var merged = map.values.toList();

    // Filter out rejected/moderated-out reviews
    merged.removeWhere((item) => item.isFlagged && item.moderationStatus == 'rejected');

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<ReviewItem>> _getLocalByProductId(int productId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT DISTINCT r.*, u.FullName as CustomerName
      FROM Review r
      LEFT JOIN User u ON r.UserID = u.UserID
      JOIN Invoice i ON r.InvoiceID = i.InvoiceID
      JOIN InvoiceDetail id ON i.InvoiceID = id.InvoiceID
      WHERE id.ProductID = ?
      ORDER BY r.CreatedAt DESC
    ''', [productId]);

    final items = <ReviewItem>[];
    for (final row in rows) {
      final reviewId = row['ReviewID'] as int;
      final images = await _loadImages(db, reviewId);
      items.add(ReviewItem.fromRow(row, imageUrls: images));
    }
    return items;
  }

  Future<List<ReviewItem>> _getFirestoreByProductId(int productId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('productIds', arrayContains: productId)
          .get();

      final items = snapshot.docs
          .map((doc) => ReviewItem.fromFirestore(doc))
          .toList();

      // Sort client-side to avoid composite index
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return items;
    } catch (e) {
      print('ReviewRepository._getFirestoreByProductId error: $e');
      return [];
    }
  }

  Future<List<String>> _loadImages(Database db, int reviewId) async {
    final rows = await db.query(
      'ReviewImage',
      columns: ['ImageUrl'],
      where: 'ReviewID = ?',
      whereArgs: [reviewId],
      orderBy: 'SortOrder ASC',
    );
    return rows.map((r) => r['ImageUrl'] as String).toList();
  }
}

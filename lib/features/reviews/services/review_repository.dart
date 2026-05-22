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
    this.firebaseUid,
    this.isDeleted = false,
    this.orderItems = const [],
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
  final String? firebaseUid;
  final bool isDeleted;
  final List<Map<String, dynamic>> orderItems;

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
      isDeleted: row['IsDeleted'] is int ? (row['IsDeleted'] as int) == 1 : false,
      firestoreDocId: row['FirestoreDocID'] as String?,
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
      firebaseUid: data['firebaseUid'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
      orderItems: (data['orderItems'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
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
    String moderationStatus = 'pending',
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
      moderationStatus: moderationStatus,
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
    required String moderationStatus,
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
      moderationStatus: moderationStatus,
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
    required String moderationStatus,
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

      // Get product/order details for display
      final detailRows = await db.rawQuery('''
        SELECT
          id.ProductID,
          id.PetID,
          p.ProductName,
          p.ImageURL,
          id.Quantity,
          id.UnitPrice,
          pet.PetName,
          pet.PetID
        FROM InvoiceDetail id
        LEFT JOIN Product p ON p.ProductID = id.ProductID
        LEFT JOIN Pet pet ON pet.PetID = id.PetID
        WHERE id.InvoiceID = ?
      ''', [invoiceId]);
      final productIds = <int>[];
      final petIds = <int>[];
      final orderItems = <Map<String, dynamic>>[];
      for (final r in detailRows) {
        final pid = r['ProductID'] as int?;
        final petId = r['PetID'] as int?;
        final itemName = (pid != null ? (r['ProductName'] as String?) : (r['PetName'] as String?)) ?? 'Sản phẩm';
        if (pid != null) productIds.add(pid);
        if (petId != null) petIds.add(petId);
        orderItems.add({
          'productId': pid,
          'petId': petId,
          'name': itemName,
          'imageUrl': r['ImageURL'] as String?,
          'quantity': (r['Quantity'] as num?)?.toInt() ?? 1,
          'unitPrice': (r['UnitPrice'] as num?)?.toDouble() ?? 0.0,
        });
      }

      final isFlagged = moderationStatus == 'flagged' || moderationStatus == 'rejected';

      final docRef = await FirebaseFirestore.instance.collection('reviews').add({
        'reviewId': reviewId,
        'invoiceId': invoiceId,
        'firebaseUid': firebaseUser?.uid ?? '',
        'customerName': customerName ?? '',
        'rating': rating,
        'content': content?.trim().isEmpty == true ? null : content?.trim(),
        'imageUrls': imageUrls ?? [],
        'productIds': productIds,
        'petIds': petIds,
        'orderItems': orderItems,
        'createdAt': now,
        'moderationStatus': moderationStatus,
        'isFlagged': isFlagged,
      });

      // Store Firestore doc ID locally so we can detect hard-deletes later
      try {
        await db.rawUpdate(
          'UPDATE Review SET FirestoreDocID = ? WHERE ReviewID = ?',
          [docRef.id, reviewId],
        );
      } catch (_) {
        // Column may not exist yet — non-fatal
      }
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
    final review = ReviewItem.fromRow(rows.first, imageUrls: images);
    if (review.isDeleted) return null;
    return review;
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
    final firestoreKeys = <String>{};
    for (final item in firestoreItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      firestoreKeys.add(key);
    }

    final map = <String, ReviewItem>{};
    for (final item in localItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      // If local item was synced to Firestore but Firestore no longer has it,
      // it was hard-deleted — skip it
      if (item.firestoreDocId != null && !firestoreKeys.contains(key)) {
        continue;
      }
      map[key] = item;
    }
    for (final item in firestoreItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      map[key] = item; // Overwrite local with Firestore (has moderation data)
    }
    var merged = map.values.toList();

    // Chỉ hiện review đã được admin duyệt (approved) hoặc review cũ chưa có moderation
    merged.removeWhere((item) =>
        item.isDeleted ||
        item.moderationStatus == 'flagged' ||
        item.moderationStatus == 'pending' ||
        item.moderationStatus == 'rejected');

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Get all reviews for a specific pet (local + Firestore)
  Future<List<ReviewItem>> getByPetId(int petId) async {
    final results = await Future.wait([
      _getLocalByPetId(petId),
      _getFirestoreByPetId(petId),
    ]);

    final localItems = results[0];
    final firestoreItems = results[1];

    final firestoreKeys = <String>{};
    for (final item in firestoreItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      firestoreKeys.add(key);
    }

    final map = <String, ReviewItem>{};
    for (final item in localItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      if (item.firestoreDocId != null && !firestoreKeys.contains(key)) {
        continue;
      }
      map[key] = item;
    }
    for (final item in firestoreItems) {
      final key = '${item.invoiceId}_${item.customerName ?? ''}';
      map[key] = item;
    }

    final merged = map.values.toList();
    // Chỉ hiện review đã được admin duyệt (approved) hoặc review cũ chưa có moderation
    merged.removeWhere((item) =>
        item.isDeleted ||
        item.moderationStatus == 'flagged' ||
        item.moderationStatus == 'pending' ||
        item.moderationStatus == 'rejected');
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

  Future<List<ReviewItem>> _getLocalByPetId(int petId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT DISTINCT r.*, u.FullName as CustomerName
      FROM Review r
      LEFT JOIN User u ON r.UserID = u.UserID
      JOIN Invoice i ON r.InvoiceID = i.InvoiceID
      JOIN InvoiceDetail id ON i.InvoiceID = id.InvoiceID
      WHERE id.PetID = ?
      ORDER BY r.CreatedAt DESC
    ''', [petId]);

    final items = <ReviewItem>[];
    for (final row in rows) {
      final reviewId = row['ReviewID'] as int;
      final images = await _loadImages(db, reviewId);
      items.add(ReviewItem.fromRow(row, imageUrls: images));
    }
    return items;
  }

  Future<List<ReviewItem>> _getFirestoreByPetId(int petId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('petIds', arrayContains: petId)
          .get();

      var items = snapshot.docs.map((doc) => ReviewItem.fromFirestore(doc)).toList();

      if (items.isEmpty) {
        final fallbackSnapshot = await FirebaseFirestore.instance.collection('reviews').get();
        items = fallbackSnapshot.docs
            .map((doc) => ReviewItem.fromFirestore(doc))
            .where((item) => item.orderItems.any((orderItem) => (orderItem['petId'] as num?)?.toInt() == petId))
            .toList();
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      print('ReviewRepository._getFirestoreByPetId error: $e');
      return [];
    }
  }

  // ── Admin methods ──────────────────────────────────────────────────

  /// Clean up orphaned local reviews whose Firestore docs no longer exist
  /// (from old hard-deletes before soft-delete was implemented)
  Future<int> cleanOrphanedLocalReviews() async {
    try {
      final db = await AppDatabase.instance;

      // Get all Firestore reviewIds (capped at 500 for performance)
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .limit(500)
          .get();
      final firestoreReviewIds = snapshot.docs
          .map((doc) => (doc.data()['reviewId'] as num?)?.toInt())
          .where((id) => id != null)
          .toSet();

      if (firestoreReviewIds.isEmpty) return 0;

      // Get all local reviewIds
      final localRows = await db.query('Review', columns: ['ReviewID']);
      var deleted = 0;
      for (final row in localRows) {
        final localId = row['ReviewID'] as int;
        if (!firestoreReviewIds.contains(localId)) {
          // This local review has no Firestore counterpart — orphaned from old hard-delete
          await db.delete('ReviewImage', where: 'ReviewID = ?', whereArgs: [localId]);
          await db.delete('Review', where: 'ReviewID = ?', whereArgs: [localId]);
          deleted++;
        }
      }
      return deleted;
    } catch (e) {
      print('ReviewRepository.cleanOrphanedLocalReviews error: $e');
      return 0;
    }
  }

  /// Get all reviews from Firestore (optionally filtered by moderationStatus)
  Future<List<ReviewItem>> getAllReviews({String? statusFilter}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('reviews');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('moderationStatus', isEqualTo: statusFilter);
      }

      final snapshot = await query.get();

      final items = snapshot.docs
          .map((doc) => ReviewItem.fromFirestore(doc))
          .where((item) => !item.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      print('ReviewRepository.getAllReviews error: $e');
      return [];
    }
  }

  /// Update moderation status on Firestore
  Future<void> updateModerationStatus(String firestoreDocId, String status) async {
    try {
      final isFlagged = status == 'flagged' || status == 'rejected';
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(firestoreDocId)
          .update({
        'moderationStatus': status,
        'isFlagged': isFlagged,
      });
    } catch (e) {
      print('ReviewRepository.updateModerationStatus error: $e');
    }
  }

  /// Soft-delete review: mark as deleted in Firestore so it disappears
  /// everywhere. Also mark local SQLite row as deleted if reviewId provided.
  Future<void> deleteFirestoreReview(String firestoreDocId, {int? reviewId}) async {
    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(firestoreDocId)
          .update({
        'isDeleted': true,
        'moderationStatus': 'deleted',
        'isFlagged': true,
      });
    } catch (e) {
      print('ReviewRepository.deleteFirestoreReview error: $e');
    }

    // Also mark local SQLite row as soft-deleted (add IsDeleted column if not exists)
    if (reviewId != null && reviewId > 0) {
      try {
        final db = await AppDatabase.instance;
        await db.rawUpdate(
          'UPDATE Review SET IsDeleted = 1 WHERE ReviewID = ?',
          [reviewId],
        );
      } catch (e) {
        // Column may not exist — ignore
        print('ReviewRepository.deleteFirestoreReview local update: $e');
      }
    }
  }

  /// Get all reviews by the current user (local + Firestore)
  Future<List<ReviewItem>> getReviewsByCurrentUser() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

    final db = await AppDatabase.instance;

    // Local reviews
    final localRows = await db.rawQuery('''
      SELECT r.*, u.FullName as CustomerName
      FROM Review r
      LEFT JOIN User u ON r.UserID = u.UserID
      WHERE r.UserID = ?
      ORDER BY r.CreatedAt DESC
    ''', [userId]);

    final localMap = <int, ReviewItem>{};
    for (final row in localRows) {
      final reviewId = row['ReviewID'] as int;
      final images = await _loadImages(db, reviewId);
      final item = ReviewItem.fromRow(row, imageUrls: images);
      if (!item.isDeleted) {
        localMap[reviewId] = item;
      }
    }

    // Firestore reviews for this user
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('firebaseUid', isEqualTo: firebaseUser.uid)
            .get();

        for (final doc in snapshot.docs) {
          final item = ReviewItem.fromFirestore(doc);
          if (item.isDeleted) continue;
          // Firestore takes precedence (has moderation data)
          localMap[item.reviewId] = item;
        }
      }
    } catch (e) {
      print('ReviewRepository.getReviewsByCurrentUser firestore: $e');
    }

    var result = localMap.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Get all invoice IDs that the current user has reviewed
  Future<List<int>> getReviewedInvoiceIdsByCurrentUser() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) return [];

    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Review',
      columns: ['InvoiceID'],
      where: 'UserID = ? AND (IsDeleted IS NULL OR IsDeleted = 0)',
      whereArgs: [userId],
    );
    final localIds = rows.map((r) => r['InvoiceID'] as int).toSet();

    // Also check Firestore for cross-device reviews
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('firebaseUid', isEqualTo: firebaseUser.uid)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;
          final invoiceId = (data['invoiceId'] as num?)?.toInt();
          if (invoiceId != null) {
            localIds.add(invoiceId);
          }
        }
      }
    } catch (e) {
      print('ReviewRepository.getReviewedInvoiceIdsByCurrentUser firestore: $e');
    }

    return localIds.toList();
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

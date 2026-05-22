import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/db/app_database.dart';
import '../../notifications/services/notification_repository.dart';

class PromotionItemV2 {
  PromotionItemV2({
    required this.promotionId,
    required this.code,
    required this.description,
    required this.discountPercent,
    required this.maxDiscount,
    required this.minOrderValue,
    required this.expiryDate,
    required this.status,
    required this.createdAt,
  });

  final int promotionId;
  final String code;
  final String description;
  final double discountPercent;
  final double maxDiscount;
  final double minOrderValue;
  final DateTime expiryDate;
  final String status;
  final DateTime createdAt;

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isActive => status == 'Active' && !isExpired;

  factory PromotionItemV2.fromRow(Map<String, dynamic> row) {
    return PromotionItemV2(
      promotionId: row['PromotionID'] as int,
      code: row['Code'] as String,
      description: row['Description'] as String,
      discountPercent: (row['DiscountPercent'] as num).toDouble(),
      maxDiscount: (row['MaxDiscount'] as num).toDouble(),
      minOrderValue: (row['MinOrderValue'] as num).toDouble(),
      expiryDate: DateTime.parse(row['ExpiryDate'] as String),
      status: row['Status'] as String,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Code': code,
      'Description': description,
      'DiscountPercent': discountPercent,
      'MaxDiscount': maxDiscount,
      'MinOrderValue': minOrderValue,
      'ExpiryDate': expiryDate.toIso8601String(),
      'Status': status,
      'CreatedAt': createdAt.toIso8601String(),
    };
  }

  /// Calculate discount amount for a given order total
  double calculateDiscount(double orderTotal) {
    if (!isActive) return 0;
    if (orderTotal < minOrderValue) return 0;
    final rawDiscount = orderTotal * discountPercent / 100;
    if (maxDiscount > 0 && rawDiscount > maxDiscount) {
      return maxDiscount;
    }
    return rawDiscount;
  }
}

class PromotionRepository {
  PromotionRepository._();
  static final PromotionRepository instance = PromotionRepository._();

  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notifyChanged() {
    changeToken.value++;
  }

  // ── List all promotions from PromotionV2 ──────────────────────────────

  Future<List<PromotionItemV2>> listAll() async {
    final results = await Future.wait([
      _listLocalPromotions(),
      _listFirestorePromotions(),
    ]);

    final localItems = results[0] as List<PromotionItemV2>;
    final firestoreItems = results[1] as List<PromotionItemV2>;

    // Dedup by promotionId
    final seen = <int>{};
    final merged = <PromotionItemV2>[];
    for (final item in [...localItems, ...firestoreItems]) {
      if (seen.add(item.promotionId)) {
        merged.add(item);
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// List only active, non-expired promotions that are valid for a given order total
  Future<List<PromotionItemV2>> listValidForOrder(double orderTotal) async {
    final all = await listAll();
    return all.where((p) {
      if (!p.isActive) return false;
      if (orderTotal < p.minOrderValue) return false;
      return true;
    }).toList();
  }

  Future<List<PromotionItemV2>> _listLocalPromotions() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('PromotionV2', orderBy: 'CreatedAt DESC');
    return rows.map(PromotionItemV2.fromRow).toList();
  }

  Future<List<PromotionItemV2>> _listFirestorePromotions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('promotions_v2')
          .get();

      print('PromotionRepository._listFirestorePromotions: got ${snapshot.docs.length} docs from Firestore');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        print('PromotionRepository._listFirestorePromotions: doc ${doc.id} -> ${data['code']}');
        return PromotionItemV2(
          promotionId: (data['promotionId'] as num).toInt(),
          code: (data['code'] as String?) ?? '',
          description: (data['description'] as String?) ?? '',
          discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
          maxDiscount: (data['maxDiscount'] as num?)?.toDouble() ?? 0,
          minOrderValue: (data['minOrderValue'] as num?)?.toDouble() ?? 0,
          expiryDate: DateTime.parse((data['expiryDate'] as String)),
          status: (data['status'] as String?) ?? 'Active',
          createdAt: DateTime.parse((data['createdAt'] as String)),
        );
      }).toList();
    } catch (e) {
      print('PromotionRepository._listFirestorePromotions error: $e');
      return [];
    }
  }

  // ── Create promotion ──────────────────────────────────────────────────

  Future<void> create({
    required String code,
    required String description,
    required double discountPercent,
    required double maxDiscount,
    required double minOrderValue,
    required DateTime expiryDate,
    String status = 'Active',
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    var promotionId = 0;

    await db.transaction((txn) async {
      // 1. Insert promotion
      promotionId = await txn.insert('PromotionV2', {
        'Code': code,
        'Description': description,
        'DiscountPercent': discountPercent,
        'MaxDiscount': maxDiscount,
        'MinOrderValue': minOrderValue,
        'ExpiryDate': expiryDate.toIso8601String(),
        'Status': status,
        'CreatedAt': nowIso,
      });

      // 2. Notify all customers
      final customers = await txn.rawQuery("SELECT UserID FROM User WHERE lower(Role) = 'customer' AND IsActive = 1");

      for (final row in customers) {
        final userId = row['UserID'] as int;
        await NotificationRepository.instance.create(
          userId: userId,
          type: 'promotion',
          title: 'Ưu đãi mới: $code',
          content: 'Giảm $discountPercent% - $description',
          txn: txn,
        );
      }
    });

    // Sync to Firestore
    _syncPromotionToFirestore(PromotionItemV2(
      promotionId: promotionId,
      code: code,
      description: description,
      discountPercent: discountPercent,
      maxDiscount: maxDiscount,
      minOrderValue: minOrderValue,
      expiryDate: expiryDate,
      status: status,
      createdAt: now,
    ));

    _notifyChanged();
  }

  // ── Per-customer usage tracking (1 code = 1 use per customer) ──────

  /// Check if a customer has already used a promotion
  Future<bool> hasCustomerUsedPromo(int promotionId, int customerId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'PromotionUsage',
      columns: ['UsageID'],
      where: 'PromotionID = ? AND CustomerID = ?',
      whereArgs: [promotionId, customerId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Record that a customer has used a promotion for an invoice
  Future<void> recordUsage({
    required int promotionId,
    required int customerId,
    required int invoiceId,
  }) async {
    final db = await AppDatabase.instance;
    try {
      await db.insert('PromotionUsage', {
        'PromotionID': promotionId,
        'CustomerID': customerId,
        'UsedAt': DateTime.now().toIso8601String(),
        'InvoiceID': invoiceId,
      });
    } catch (e) {
      // UNIQUE constraint may fire if already recorded; that's fine
      print('PromotionRepository.recordUsage: $e');
    }
  }

  /// Resolve customerId from userId
  Future<int> resolveCustomerId(int userId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'Customer',
      columns: ['CustomerID'],
      where: 'UserID = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['CustomerID'] as int;
    return 0;
  }

  // ── Toggle promotion status ─────────────────────────────────────────

  Future<void> toggleStatus(int promotionId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'PromotionV2',
      columns: ['Status'],
      where: 'PromotionID = ?',
      whereArgs: [promotionId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final currentStatus = rows.first['Status'] as String? ?? 'Active';
    final newStatus = currentStatus == 'Active' ? 'Inactive' : 'Active';

    await db.update(
      'PromotionV2',
      {'Status': newStatus},
      where: 'PromotionID = ?',
      whereArgs: [promotionId],
    );

    // Sync to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('promotions_v2')
          .doc(promotionId.toString())
          .update({'status': newStatus});
    } catch (e) {
      print('PromotionRepository.toggleStatus Firestore error: $e');
    }

    _notifyChanged();
  }

  // ── Firestore sync ──────────────────────────────────────────────────

  void _syncPromotionToFirestore(PromotionItemV2 item) {
    _doSyncPromotionToFirestore(item);
  }

  Future<void> _doSyncPromotionToFirestore(PromotionItemV2 item) async {
    try {
      await FirebaseFirestore.instance
          .collection('promotions_v2')
          .doc(item.promotionId.toString())
          .set({
        'promotionId': item.promotionId,
        'code': item.code,
        'description': item.description,
        'discountPercent': item.discountPercent,
        'maxDiscount': item.maxDiscount,
        'minOrderValue': item.minOrderValue,
        'expiryDate': item.expiryDate.toIso8601String(),
        'status': item.status,
        'createdAt': item.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('PromotionRepository._doSyncPromotionToFirestore error: $e');
    }
  }
}

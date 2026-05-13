import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/db/app_database.dart';
import '../../notifications/services/notification_repository.dart';

class PromotionItem {
  PromotionItem({
    required this.promotionId,
    required this.code,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final int promotionId;
  final String code;
  final String description;
  final String status;
  final DateTime createdAt;

  factory PromotionItem.fromRow(Map<String, dynamic> row) {
    return PromotionItem(
      promotionId: row['PromotionID'] as int,
      code: row['Code'] as String,
      description: row['Description'] as String,
      status: row['Status'] as String,
      createdAt: DateTime.parse(row['CreatedAt'] as String),
    );
  }
}

class PromotionRepository {
  PromotionRepository._();
  static final PromotionRepository instance = PromotionRepository._();

  final ValueNotifier<int> changeToken = ValueNotifier<int>(0);

  void _notifyChanged() {
    changeToken.value++;
  }

  Future<List<PromotionItem>> listAll() async {
    final results = await Future.wait([
      _listLocalPromotions(),
      _listFirestorePromotions(),
    ]);

    final localItems = results[0] as List<PromotionItem>;
    final firestoreItems = results[1] as List<PromotionItem>;

    // Dedup by promotionId
    final seen = <int>{};
    final merged = <PromotionItem>[];
    for (final item in [...localItems, ...firestoreItems]) {
      if (seen.add(item.promotionId)) {
        merged.add(item);
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<List<PromotionItem>> _listLocalPromotions() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('Promotion', orderBy: 'CreatedAt DESC');
    return rows.map(PromotionItem.fromRow).toList();
  }

  Future<List<PromotionItem>> _listFirestorePromotions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('promotions')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PromotionItem(
          promotionId: (data['promotionId'] as num).toInt(),
          code: (data['code'] as String?) ?? '',
          description: (data['description'] as String?) ?? '',
          status: (data['status'] as String?) ?? 'Active',
          createdAt: DateTime.parse((data['createdAt'] as String)),
        );
      }).toList();
    } catch (e) {
      print('PromotionRepository._listFirestorePromotions error: $e');
      return [];
    }
  }

  Future<void> create({
    required String code,
    required String description,
    String status = 'Active',
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    var promotionId = 0;

    await db.transaction((txn) async {
      // 1. Insert promotion
      promotionId = await txn.insert('Promotion', {
        'Code': code,
        'Description': description,
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
          content: description,
          txn: txn,
        );
      }
    });

    // Sync to Firestore
    _syncPromotionToFirestore(PromotionItem(
      promotionId: promotionId,
      code: code,
      description: description,
      status: status,
      createdAt: now,
    ));

    _notifyChanged();
  }

  // ── Firestore sync ──────────────────────────────────────────────────

  void _syncPromotionToFirestore(PromotionItem item) {
    _doSyncPromotionToFirestore(item);
  }

  Future<void> _doSyncPromotionToFirestore(PromotionItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('promotions')
          .doc(item.promotionId.toString())
          .set({
        'promotionId': item.promotionId,
        'code': item.code,
        'description': item.description,
        'status': item.status,
        'createdAt': item.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('PromotionRepository._doSyncPromotionToFirestore error: $e');
    }
  }
}

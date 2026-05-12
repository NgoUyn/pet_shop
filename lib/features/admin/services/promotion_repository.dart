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
    final db = await AppDatabase.instance;
    final rows = await db.query('Promotion', orderBy: 'CreatedAt DESC');
    return rows.map(PromotionItem.fromRow).toList();
  }

  Future<void> create({
    required String code,
    required String description,
    String status = 'Active',
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Insert promotion
      await txn.insert('Promotion', {
        'Code': code,
        'Description': description,
        'Status': status,
        'CreatedAt': now.toIso8601String(),
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

    _notifyChanged();
  }
}

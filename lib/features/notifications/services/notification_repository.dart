import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';

class AppNotificationItem {
  AppNotificationItem({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.readAt,
    required this.userId,
    this.referenceId,
    this.referenceType,
  });

  final int notificationId;
  final int userId;
  final String type;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final int? referenceId;
  final String? referenceType;

  static AppNotificationItem fromRow(Map<String, Object?> row) {
    final createdAtRaw = row['CreatedAt'] as String;
    final readAtRaw = row['ReadAt'] as String?;

    return AppNotificationItem(
      notificationId: row['NotificationID'] as int,
      userId: row['UserID'] as int,
      type: (row['Type'] as String?) ?? 'general',
      title: (row['Title'] as String?) ?? '',
      content: (row['Content'] as String?) ?? '',
      createdAt: DateTime.parse(createdAtRaw),
      isRead: (row['IsRead'] as int?) == 1,
      readAt: readAtRaw == null ? null : DateTime.parse(readAtRaw),
      referenceId: row['ReferenceID'] as int?,
      referenceType: row['ReferenceType'] as String?,
    );
  }
}

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  Future<int> create({
    int? userId,
    String type = 'general',
    required String title,
    required String content,
    DateTime? createdAt,
    int? referenceId,
    String? referenceType,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await AppDatabase.instance;

    final normalizedTitle = title.trim();
    final normalizedContent = content.trim();
    if (normalizedTitle.isEmpty) {
      throw StateError('Tên thông báo không được để trống');
    }
    if (normalizedContent.isEmpty) {
      throw StateError('Nội dung thông báo không được để trống');
    }

    final normalizedType = type.trim().isEmpty ? 'general' : type.trim();
    final resolvedUserId = userId ?? AuthSession.instance.currentUserId.value;
    if (resolvedUserId == null) {
      throw StateError('Không tìm thấy user để tạo thông báo');
    }
    final createdAtIso = (createdAt ?? DateTime.now()).toIso8601String();

    return db.insert('AppNotification', {
      'UserID': resolvedUserId,
      'Type': normalizedType,
      'Title': normalizedTitle,
      'Content': normalizedContent,
      'CreatedAt': createdAtIso,
      'IsRead': 0,
      'ReadAt': null,
      'ReferenceID': referenceId,
      'ReferenceType': referenceType,
    });
  }

  Future<List<AppNotificationItem>> listForCurrentUser({int limit = 50}) async {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) {
      print('NotificationRepository: currentUserId is null');
      return [];
    }

    final db = await AppDatabase.instance;
    final rows = await db.query(
      'AppNotification',
      where: 'UserID = ?',
      whereArgs: [currentUserId],
      orderBy: 'CreatedAt DESC',
      limit: limit,
    );

    print('NotificationRepository.listForCurrentUser: userId=$currentUserId, found ${rows.length} notifications');
    return rows.map(AppNotificationItem.fromRow).toList();
  }

  Future<int> unreadCountForCurrentUser() async {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) {
      return 0;
    }

    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS Cnt
      FROM AppNotification
      WHERE UserID = ?
        AND IsRead = 0
      ''',
      [currentUserId],
    );

    if (rows.isEmpty) return 0;
    return (rows.first['Cnt'] as int?) ?? 0;
  }

  Future<void> markAsRead(int notificationId) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'AppNotification',
      {
        'IsRead': 1,
        'ReadAt': now,
      },
      where: 'NotificationID = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllAsReadForCurrentUser() async {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) {
      return;
    }

    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'AppNotification',
      {
        'IsRead': 1,
        'ReadAt': now,
      },
      where: 'UserID = ? AND IsRead = 0',
      whereArgs: [currentUserId],
    );
  }
}

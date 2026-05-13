import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    this.firestoreDocId,
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
  final String? firestoreDocId;

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
  }) async {
    final db = await AppDatabase.instance;

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
      return [];
    }

    // Fetch local + Firestore in parallel
    final results = await Future.wait([
      _listLocal(currentUserId, limit),
      _listFromFirestore(),
    ]);

    final localItems = results[0] as List<AppNotificationItem>;
    final firestoreItems = results[1] as List<AppNotificationItem>;

    // Merge and dedup by (referenceId, referenceType, title)
    final seen = <String>{};
    final merged = <AppNotificationItem>[];

    for (final item in [...localItems, ...firestoreItems]) {
      final key = '${item.referenceId ?? 0}_${item.referenceType ?? ''}_${item.title}';
      if (seen.add(key)) {
        merged.add(item);
      }
    }

    // Sort by createdAt descending
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit < merged.length) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  Future<List<AppNotificationItem>> _listLocal(int currentUserId, int limit) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'AppNotification',
      where: 'UserID = ?',
      whereArgs: [currentUserId],
      orderBy: 'CreatedAt DESC',
      limit: limit,
    );
    return rows.map(AppNotificationItem.fromRow).toList();
  }

  Future<List<AppNotificationItem>> _listFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .limit(50)
          .get();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAtStr = (data['createdAt'] as String?) ?? DateTime.now().toIso8601String();
        final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        return AppNotificationItem(
          notificationId: 0, // Firestore origin
          userId: 0,
          type: (data['type'] as String?) ?? 'general',
          title: (data['title'] as String?) ?? '',
          content: (data['content'] as String?) ?? '',
          createdAt: createdAt,
          isRead: (data['isRead'] as bool?) ?? false,
          referenceId: (data['referenceId'] as num?)?.toInt(),
          referenceType: data['referenceType'] as String?,
          firestoreDocId: doc.id,
        );
      }).toList();

      // Sort client-side to avoid composite index requirement
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return items;
    } catch (e) {
      print('NotificationRepository._listFromFirestore error: $e');
      return [];
    }
  }

  Future<int> unreadCountForCurrentUser() async {
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId == null) {
      return 0;
    }

    // Count local + Firestore in parallel
    final results = await Future.wait([
      _unreadCountLocal(currentUserId),
      _unreadCountFromFirestore(),
    ]);

    return (results[0] as int) + (results[1] as int);
  }

  Future<int> _unreadCountLocal(int currentUserId) async {
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

  Future<int> _unreadCountFromFirestore() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .get();

      // Count unread client-side to avoid composite index requirement
      return snapshot.docs.where((doc) => doc.data()['isRead'] == false).length;
    } catch (e) {
      print('NotificationRepository._unreadCountFromFirestore error: $e');
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId, {String? firestoreDocId}) async {
    // Mark local notification as read
    if (notificationId > 0) {
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

    // Mark Firestore notification as read
    if (firestoreDocId != null && firestoreDocId.isNotEmpty) {
      await _markFirestoreDocRead(firestoreDocId);
    }
  }

  Future<void> _markFirestoreDocRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});
    } catch (e) {
      print('NotificationRepository._markFirestoreDocRead error: $e');
    }
  }

  Future<void> markAllAsReadForCurrentUser() async {
    // Mark local
    final currentUserId = AuthSession.instance.currentUserId.value;
    if (currentUserId != null) {
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

    // Mark Firestore
    await _markAllFirestoreRead();
  }

  Future<void> _markAllFirestoreRead() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('firebaseUid', isEqualTo: firebaseUser.uid)
          .get();

      // Filter unread client-side to avoid composite index requirement
      for (final doc in snapshot.docs) {
        if (doc.data()['isRead'] == false) {
          await doc.reference.update({'isRead': true});
        }
      }
    } catch (e) {
      print('NotificationRepository._markAllFirestoreRead error: $e');
    }
  }
}

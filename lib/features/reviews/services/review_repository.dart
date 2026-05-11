import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';

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

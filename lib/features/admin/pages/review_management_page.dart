import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../reviews/services/review_repository.dart';

const _statusFilters = [
  {'label': 'Tất cả', 'value': null},
  {'label': 'Đã duyệt', 'value': 'approved'},
  {'label': 'Bị gắn cờ', 'value': 'flagged'},
  {'label': 'Chờ duyệt', 'value': 'pending'},
  {'label': 'Bị từ chối', 'value': 'rejected'},
];

class ReviewManagementPage extends StatefulWidget {
  const ReviewManagementPage({super.key});

  @override
  State<ReviewManagementPage> createState() => _ReviewManagementPageState();
}

class _ReviewManagementPageState extends State<ReviewManagementPage> {
  String? _selectedFilter;
  int? _starFilter;
  late Future<List<ReviewItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWithCleanup();
  }

  Future<List<ReviewItem>> _loadWithCleanup() async {
    await ReviewRepository.instance.cleanOrphanedLocalReviews();
    return _loadAndHydrate();
  }

  Future<List<ReviewItem>> _loadAndHydrate({String? statusFilter}) async {
    final reviews = await ReviewRepository.instance.getAllReviews(statusFilter: statusFilter);
    return _hydrateOrderItems(reviews);
  }

  /// Fill in missing orderItems for old reviews by loading from local SQLite
  /// or Firestore orders collection.
  Future<List<ReviewItem>> _hydrateOrderItems(List<ReviewItem> reviews) async {
    final needsHydration = reviews.where((r) => r.orderItems.isEmpty).toList();
    if (needsHydration.isEmpty) return reviews;

    try {
      final db = await AppDatabase.instance;

      for (final review in needsHydration) {
        // Try local SQLite first
        final localRows = await db.rawQuery('''
          SELECT
            id.ProductID, p.ProductName, p.ImageURL,
            id.Quantity, id.UnitPrice,
            pet.PetName, pet.PetID
          FROM InvoiceDetail id
          LEFT JOIN Product p ON p.ProductID = id.ProductID
          LEFT JOIN Pet pet ON pet.PetID = id.PetID
          WHERE id.InvoiceID = ?
        ''', [review.invoiceId]);

        if (localRows.isNotEmpty) {
          review.orderItems.addAll(localRows.map((r) {
            final pid = r['ProductID'] as int?;
            final petId = r['PetID'] as int?;
            return {
              'productId': pid,
              'petId': petId,
              'name': (pid != null ? (r['ProductName'] as String?) : (r['PetName'] as String?)) ?? 'Sản phẩm',
              'imageUrl': r['ImageURL'] as String?,
              'quantity': (r['Quantity'] as num?)?.toInt() ?? 1,
              'unitPrice': (r['UnitPrice'] as num?)?.toDouble() ?? 0.0,
            };
          }));
          continue;
        }

        // Fallback: Firestore orders doc
        try {
          final doc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(review.invoiceId.toString())
              .get();
          if (doc.exists) {
            final data = doc.data()!;
            final items = (data['items'] as List<dynamic>?) ?? [];
            review.orderItems.addAll(items.map((item) {
              final m = Map<String, dynamic>.from(item as Map);
              final pid = (m['productId'] as num?)?.toInt();
              final petId = (m['petId'] as num?)?.toInt();
              return {
                'productId': pid,
                'petId': petId,
                'name': m['productName'] ?? m['petName'] ?? 'Sản phẩm',
                'imageUrl': null,
                'quantity': (m['quantity'] as num?)?.toInt() ?? 1,
                'unitPrice': (m['unitPrice'] as num?)?.toDouble() ?? 0.0,
              };
            }));
          }
        } catch (_) {}
      }
    } catch (_) {}

    return reviews;
  }

  void _loadReviews() {
    setState(() {
      _future = _loadAndHydrate(statusFilter: _selectedFilter);
    });
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'approved' => 'Đã duyệt',
      'flagged' => 'Bị gắn cờ',
      'pending' => 'Chờ duyệt',
      'rejected' => 'Bị từ chối',
      _ => 'Không rõ',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'approved' => Colors.green,
      'flagged' => Colors.orange,
      'pending' => Colors.grey,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approve(ReviewItem item) async {
    if (item.firestoreDocId == null) return;
    await ReviewRepository.instance.updateModerationStatus(item.firestoreDocId!, 'approved');
    _loadReviews();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã phê duyệt đánh giá'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _reject(ReviewItem item) async {
    if (item.firestoreDocId == null) return;
    await ReviewRepository.instance.updateModerationStatus(item.firestoreDocId!, 'rejected');

    // Notify the user
    if (item.firebaseUid != null && item.firebaseUid!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'firebaseUid': item.firebaseUid,
          'type': 'review',
          'title': 'Đánh giá của bạn đã bị từ chối',
          'content': 'Đánh giá của bạn đã bị quản trị viên từ chối do vi phạm tiêu chuẩn cộng đồng.',
          'referenceId': item.reviewId,
          'referenceType': 'review',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
        });
      } catch (_) {}
    }

    _loadReviews();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối đánh giá'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _delete(ReviewItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: const Text('Bạn có chắc muốn xoá đánh giá này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (item.firestoreDocId != null) {
      await ReviewRepository.instance.deleteFirestoreReview(
        item.firestoreDocId!,
        reviewId: item.reviewId,
      );
    }
    _loadReviews();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá đánh giá'), duration: Duration(seconds: 1)),
      );
    }
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 14,
          color: const Color(0xFFFFB300),
        );
      }),
    );
  }

  String _formatPrice(dynamic value) {
    final numVal = value is double ? value : (value as num).toDouble();
    final formatted = numVal.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '$bufferđ';
  }

  Widget _buildOrderItems(List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sản phẩm đã mua:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: item['imageUrl'] is String
                          ? Image.network(item['imageUrl'] as String, width: 40, height: 40, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(width: 40, height: 40, color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_outlined, size: 20, color: Colors.grey)))
                          : Container(width: 40, height: 40, color: Colors.grey.shade200,
                              child: const Icon(Icons.pets, size: 20, color: Colors.grey)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] as String? ?? 'Sản phẩm',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('SL: ${item['quantity']} x ${_formatPrice(item['unitPrice'])}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewItem item) {
    final statusColor = _statusColor(item.moderationStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: customer name + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.customerName ?? 'Khách hàng',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(item.moderationStatus),
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Rating + date
            Row(
              children: [
                _buildStars(item.rating),
                const SizedBox(width: 8),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Order items
            if (item.orderItems.isNotEmpty)
              _buildOrderItems(item.orderItems),

            // Content
            if (item.content != null && item.content!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item.content!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                ),
              ),

            // Images
            if (item.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.imageUrls[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.moderationStatus != 'approved')
                  TextButton.icon(
                    onPressed: () => _approve(item),
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                    label: const Text('Phê duyệt', style: TextStyle(color: Colors.green, fontSize: 13)),
                  ),
                const SizedBox(width: 4),
                if (item.moderationStatus != 'rejected')
                  TextButton.icon(
                    onPressed: () => _reject(item),
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.orange),
                    label: const Text('Từ chối', style: TextStyle(color: Colors.orange, fontSize: 13)),
                  ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _delete(item),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Xoá', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý đánh giá'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips — status
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((f) {
                  final isSelected = _selectedFilter == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(f['label']!),
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = f['value'] as String?;
                        });
                        _loadReviews();
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Star filter chips
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...[5, 4, 3, 2, 1].map((star) {
                    final isSelected = _starFilter == star;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: Icon(isSelected ? Icons.star : Icons.star_border, size: 16, color: const Color(0xFFFFB300)),
                        label: Text('$star sao'),
                        onSelected: (_) {
                          setState(() {
                            _starFilter = isSelected ? null : star;
                          });
                        },
                        selectedColor: const Color(0xFFFFF3E0),
                        checkmarkColor: const Color(0xFFFFB300),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Review list
          Expanded(
            child: FutureBuilder<List<ReviewItem>>(
              future: _future,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: AppColors.textLight)),
                  );
                }

                final items = (snapshot.data ?? []);
                final filtered = _starFilter == null
                    ? items
                    : items.where((r) => r.rating == _starFilter).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Không có đánh giá nào', style: TextStyle(color: AppColors.textLight)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadReviews(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildReviewCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

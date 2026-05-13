import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
  late Future<List<ReviewItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ReviewRepository.instance.getAllReviews();
  }

  void _loadReviews() {
    setState(() {
      _future = ReviewRepository.instance.getAllReviews(statusFilter: _selectedFilter);
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
      await ReviewRepository.instance.deleteFirestoreReview(item.firestoreDocId!);
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
          // Filter chips
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

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Không có đánh giá nào', style: TextStyle(color: AppColors.textLight)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadReviews(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _buildReviewCard(items[i]),
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

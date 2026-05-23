import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../orders/services/order_repository.dart';
import '../services/review_repository.dart';
import 'review_page.dart';

/// Trang "Đánh giá của tôi" với 2 tab: Đã đánh giá / Chưa đánh giá
class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đánh giá của tôi'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Đã đánh giá'),
            Tab(text: 'Chưa đánh giá'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ReviewedTab(),
          _UnreviewedTab(),
        ],
      ),
    );
  }
}

/// Tab "Đã đánh giá" — hiện danh sách review của user
class _ReviewedTab extends StatefulWidget {
  const _ReviewedTab();

  @override
  State<_ReviewedTab> createState() => _ReviewedTabState();
}

enum _ReviewTypeFilter { all, pet, product }

class _ReviewedTabState extends State<_ReviewedTab> {
  List<ReviewItem> _reviews = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _ReviewTypeFilter _typeFilter = _ReviewTypeFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final reviews = await ReviewRepository.instance.getReviewsByCurrentUser();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ReviewItem> get _filteredReviews {
    var result = _reviews.toList();

    // Filter by type (all / pet / product)
    if (_typeFilter == _ReviewTypeFilter.pet) {
      result = result.where((r) =>
          r.orderItems.any((item) => item['petId'] != null)).toList();
    } else if (_typeFilter == _ReviewTypeFilter.product) {
      result = result.where((r) =>
          r.orderItems.any((item) => item['productId'] != null)).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((r) {
        // Search by content
        if (r.content != null && r.content!.toLowerCase().contains(query)) {
          return true;
        }
        // Search by product/pet name
        for (final item in r.orderItems) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          if (name.contains(query)) return true;
        }
        // Search by date (dd/mm/yyyy format)
        final dateStr =
            '${r.createdAt.day.toString().padLeft(2, '0')}/${r.createdAt.month.toString().padLeft(2, '0')}/${r.createdAt.year}';
        if (dateStr.contains(query)) return true;
        return false;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredReviews;

    return Column(
      children: [
        // Search bar
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm đánh giá...',
              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textLight),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // Filter chips
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              _buildFilterChip('Tất cả', _ReviewTypeFilter.all),
              const SizedBox(width: 8),
              _buildFilterChip('Thú cưng', _ReviewTypeFilter.pet),
              const SizedBox(width: 8),
              _buildFilterChip('Sản phẩm', _ReviewTypeFilter.product),
            ],
          ),
        ),
        // Review list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_outlined, size: 56, color: AppColors.textLight),
                      SizedBox(height: 12),
                      Text('Không tìm thấy đánh giá nào',
                          style: TextStyle(color: AppColors.textLight, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _ReviewCard(review: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, _ReviewTypeFilter filter) {
    final isSelected = _typeFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onSelected: (_) => setState(() => _typeFilter = filter),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// Card hiển thị một review trong tab "Đã đánh giá"
class _ReviewCard extends StatelessWidget {
  final ReviewItem review;

  const _ReviewCard({required this.review});

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
            // Order items
            if (review.orderItems.isNotEmpty)
              ...review.orderItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: item['imageUrl'] is String
                              ? CachedNetworkImage(imageUrl: item['imageUrl'] as String,
                                  width: 48, height: 48, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                      width: 48, height: 48,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_outlined,
                                          size: 24, color: Colors.grey)))
                              : Container(
                                  width: 48, height: 48,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.pets,
                                      size: 24, color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['name'] as String? ?? 'Sản phẩm',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  )),

            // Rating stars
            Row(
              children: [
                ...List.generate(5, (i) => Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: const Color(0xFFFFB300),
                    )),
                const SizedBox(width: 8),
                Text(
                  _formatDate(review.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Content
            if (review.content != null && review.content!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  review.content!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                ),
              ),

            // Images
            if (review.imageUrls.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: review.imageUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),

            // Moderation status
            if (review.moderationStatus == 'flagged' ||
                review.moderationStatus == 'pending')
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Đang chờ duyệt',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            if (review.moderationStatus == 'rejected')
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Bị từ chối',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tab "Chưa đánh giá" — hiện danh sách đơn hàng Completed chưa có review
class _UnreviewedTab extends StatefulWidget {
  const _UnreviewedTab();

  @override
  State<_UnreviewedTab> createState() => _UnreviewedTabState();
}

class _UnreviewedTabState extends State<_UnreviewedTab> {
  List<OrderInfo> _unreviewedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnreviewed();
  }

  Future<void> _loadUnreviewed() async {
    setState(() => _isLoading = true);
    try {
      // Lấy tất cả đơn hàng Completed của user
      final allOrders = await OrderRepository.instance
          .getOrdersForCurrentUser(statusFilter: 'Completed');

      // Lấy danh sách invoiceId đã review
      final reviewedIds =
          await ReviewRepository.instance.getReviewedInvoiceIdsByCurrentUser();
      final reviewedSet = reviewedIds.toSet();

      // Lọc ra đơn chưa review
      final unreviewed =
          allOrders.where((o) => !reviewedSet.contains(o.invoiceId)).toList();

      if (mounted) {
        setState(() {
          _unreviewedOrders = unreviewed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_unreviewedOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Tất cả đơn hàng đã được đánh giá',
                style: TextStyle(color: AppColors.textLight, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUnreviewed,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _unreviewedOrders.length,
        itemBuilder: (_, i) => _UnreviewedOrderCard(
          order: _unreviewedOrders[i],
          onReview: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReviewPage(invoiceId: _unreviewedOrders[i].invoiceId),
              ),
            );
            if (result == true) {
              _loadUnreviewed();
            }
          },
        ),
      ),
    );
  }
}

/// Card hiển thị đơn hàng chưa đánh giá
class _UnreviewedOrderCard extends StatelessWidget {
  final OrderInfo order;
  final VoidCallback onReview;

  const _UnreviewedOrderCard({
    required this.order,
    required this.onReview,
  });

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
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

  @override
  Widget build(BuildContext context) {
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
            // Header: mã đơn + tổng tiền
            Row(
              children: [
                const Text('Đơn hàng #',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                Text(order.invoiceId.toString(),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const Spacer(),
                Text(_formatPrice(order.totalAmount),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),

            // Danh sách sản phẩm trong đơn
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 16, color: AppColors.textLight),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('x${item.quantity}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                )),

            const SizedBox(height: 8),

            // Nút đánh giá
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Đánh giá'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

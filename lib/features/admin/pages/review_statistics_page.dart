import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

// ─── Data Models ───────────────────────────────────────────────────────

class _ReviewStats {
  final int totalReviews;
  final double averageRating;
  final int reviewsWithImages;
  final Map<int, int> ratingDistribution; // 1..5
  final List<_MonthlyComparison> monthlyComparisons;
  final List<_TopReviewedProduct> topProducts;
  final List<_TopReviewedProduct> topPets;
  final int previousMonthReviews;
  final int currentMonthReviews;
  final double previousMonthAvgRating;
  final double currentMonthAvgRating;

  _ReviewStats({
    required this.totalReviews,
    required this.averageRating,
    required this.reviewsWithImages,
    required this.ratingDistribution,
    required this.monthlyComparisons,
    required this.topProducts,
    required this.topPets,
    required this.previousMonthReviews,
    required this.currentMonthReviews,
    required this.previousMonthAvgRating,
    required this.currentMonthAvgRating,
  });

  factory _ReviewStats.empty() => _ReviewStats(
        totalReviews: 0,
        averageRating: 0,
        reviewsWithImages: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        monthlyComparisons: [],
        topProducts: [],
        topPets: [],
        previousMonthReviews: 0,
        currentMonthReviews: 0,
        previousMonthAvgRating: 0,
        currentMonthAvgRating: 0,
      );
}

class _MonthlyComparison {
  final String label; // 'T1', 'T2', ...
  final int reviewCount;
  final double avgRating;

  _MonthlyComparison({
    required this.label,
    required this.reviewCount,
    required this.avgRating,
  });
}

class _TopReviewedProduct {
  final String name;
  final int reviewCount;
  final double avgRating;
  final String? imageUrl;

  _TopReviewedProduct({
    required this.name,
    required this.reviewCount,
    required this.avgRating,
    this.imageUrl,
  });
}

// ─── Main Page ─────────────────────────────────────────────────────────

class ReviewStatisticsPage extends StatefulWidget {
  const ReviewStatisticsPage({super.key});

  @override
  State<ReviewStatisticsPage> createState() => _ReviewStatisticsPageState();
}

class _ReviewStatisticsPageState extends State<ReviewStatisticsPage> {
  bool _loading = true;
  _ReviewStats _stats = _ReviewStats.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('reviews').get();
      final allReviews =
          snapshot.docs.map((doc) => doc.data()).toList();

      // Filter out deleted reviews
      final activeReviews = allReviews
          .where((data) => data['isDeleted'] != true)
          .toList();

      // ── Tổng quan ──
      final totalReviews = activeReviews.length;

      // Điểm trung bình
      double totalRating = 0;
      for (final data in activeReviews) {
        totalRating += (data['rating'] as num?)?.toDouble() ?? 0;
      }
      final averageRating =
          totalReviews > 0 ? totalRating / totalReviews : 0.0;

      // Số đánh giá có ảnh
      final reviewsWithImages = activeReviews
          .where((data) {
            final urls = data['imageUrls'] as List<dynamic>? ?? [];
            return urls.isNotEmpty;
          })
          .length;

      // ── Phân bố sao ──
      final ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final data in activeReviews) {
        final rating = (data['rating'] as num?)?.toInt() ?? 0;
        if (rating >= 1 && rating <= 5) {
          ratingDistribution[rating] =
              (ratingDistribution[rating] ?? 0) + 1;
        }
      }

      // ── So sánh theo tháng ──
      final now = DateTime.now();
      final currentMonthStart =
          DateTime(now.year, now.month, 1);
      final previousMonthStart =
          DateTime(now.year, now.month - 1, 1);

      int currentMonthReviews = 0;
      int previousMonthReviews = 0;
      double currentMonthRatingSum = 0;
      double previousMonthRatingSum = 0;

      for (final data in activeReviews) {
        final createdAtStr = data['createdAt'] as String? ?? '';
        if (createdAtStr.isEmpty) continue;
        try {
          final date = DateTime.parse(createdAtStr);
          final rating = (data['rating'] as num?)?.toDouble() ?? 0;

          if (date.isAfter(currentMonthStart) ||
              date.isAtSameMomentAs(currentMonthStart)) {
            currentMonthReviews++;
            currentMonthRatingSum += rating;
          } else if (date.isAfter(previousMonthStart) ||
              date.isAtSameMomentAs(previousMonthStart)) {
            previousMonthReviews++;
            previousMonthRatingSum += rating;
          }
        } catch (_) {}
      }

      final currentMonthAvgRating = currentMonthReviews > 0
          ? currentMonthRatingSum / currentMonthReviews
          : 0.0;
      final previousMonthAvgRating = previousMonthReviews > 0
          ? previousMonthRatingSum / previousMonthReviews
          : 0.0;

      // ── Biểu đồ xu hướng 6 tháng ──
      final monthlyComparisons = <_MonthlyComparison>[];
      for (var i = 5; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 1);
        int count = 0;
        double sum = 0;
        for (final data in activeReviews) {
          final createdAtStr = data['createdAt'] as String? ?? '';
          if (createdAtStr.isEmpty) continue;
          try {
            final date = DateTime.parse(createdAtStr);
            if ((date.isAfter(monthStart) ||
                    date.isAtSameMomentAs(monthStart)) &&
                date.isBefore(monthEnd)) {
              count++;
              sum += (data['rating'] as num?)?.toDouble() ?? 0;
            }
          } catch (_) {}
        }
        monthlyComparisons.add(_MonthlyComparison(
          label: 'T${monthStart.month}',
          reviewCount: count,
          avgRating: count > 0 ? sum / count : 0,
        ));
      }

      // ── Sản phẩm được đánh giá nhiều ──
      final productReviewMap = <String, _ProductReviewAgg>{};
      final petReviewMap = <String, _ProductReviewAgg>{};

      for (final data in activeReviews) {
        final orderItems =
            data['orderItems'] as List<dynamic>? ?? [];
        for (final item in orderItems) {
          final itemMap = item as Map<String, dynamic>;
          final name =
              (itemMap['name'] as String? ?? '').trim();
          final rating =
              (data['rating'] as num?)?.toInt() ?? 0;
          final imageUrl = itemMap['imageUrl'] as String?;
          final isPet = itemMap['petId'] != null;

          if (name.isEmpty) continue;

          final map = isPet ? petReviewMap : productReviewMap;
          map.update(
            name,
            (existing) => _ProductReviewAgg(
              name: existing.name,
              reviewCount: existing.reviewCount + 1,
              totalRating: existing.totalRating + rating.toDouble(),
              imageUrl: existing.imageUrl ?? imageUrl,
            ),
            ifAbsent: () => _ProductReviewAgg(
              name: name,
              reviewCount: 1,
              totalRating: rating.toDouble(),
              imageUrl: imageUrl,
            ),
          );
        }
      }

      final topProducts = productReviewMap.values.toList()
        ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      final topPets = petReviewMap.values.toList()
        ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

      if (!mounted) return;
      setState(() {
        _stats = _ReviewStats(
          totalReviews: totalReviews,
          averageRating: averageRating,
          reviewsWithImages: reviewsWithImages,
          ratingDistribution: ratingDistribution,
          monthlyComparisons: monthlyComparisons,
          topProducts: topProducts.take(5).map((p) => _TopReviewedProduct(
                name: p.name,
                reviewCount: p.reviewCount,
                avgRating: p.reviewCount > 0
                    ? p.totalRating / p.reviewCount
                    : 0,
                imageUrl: p.imageUrl,
              )).toList(),
          topPets: topPets.take(5).map((p) => _TopReviewedProduct(
                name: p.name,
                reviewCount: p.reviewCount,
                avgRating: p.reviewCount > 0
                    ? p.totalRating / p.reviewCount
                    : 0,
                imageUrl: p.imageUrl,
              )).toList(),
          previousMonthReviews: previousMonthReviews,
          currentMonthReviews: currentMonthReviews,
          previousMonthAvgRating: previousMonthAvgRating,
          currentMonthAvgRating: currentMonthAvgRating,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thống kê đánh giá'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 4 thẻ tổng quan ──
                  _buildSummaryRow(),
                  const SizedBox(height: 16),

                  // ── Biểu đồ phân bố sao ──
                  _SectionCard(
                    title: 'Phân bố đánh giá theo số sao',
                    child: _StarDistributionChart(
                      distribution: _stats.ratingDistribution,
                      total: _stats.totalReviews,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Biểu đồ xu hướng theo tháng ──
                  _SectionCard(
                    title: 'Xu hướng đánh giá theo tháng',
                    child: _MonthlyTrendChart(
                      items: _stats.monthlyComparisons,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── So sánh tháng trước và tháng này ──
                  _SectionCard(
                    title: 'So sánh tháng trước & tháng này',
                    child: _MonthComparisonCard(
                      currentReviews: _stats.currentMonthReviews,
                      previousReviews: _stats.previousMonthReviews,
                      currentAvgRating: _stats.currentMonthAvgRating,
                      previousAvgRating: _stats.previousMonthAvgRating,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Sản phẩm được đánh giá nhiều ──
                  _SectionCard(
                    title: 'Phụ kiện được đánh giá nhiều nhất',
                    child: _TopReviewedList(items: _stats.topProducts),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Thú cưng được đánh giá nhiều nhất',
                    child: _TopReviewedList(items: _stats.topPets),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.maxWidth > 360 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.rate_review_outlined,
                iconColor: const Color(0xFF5B8DEF),
                value: '${_stats.totalReviews}',
                label: 'Tổng đánh giá',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.star_half,
                iconColor: const Color(0xFFFFB300),
                value: _stats.averageRating.toStringAsFixed(1),
                label: 'Điểm trung bình',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.photo_camera_outlined,
                iconColor: const Color(0xFF27AE60),
                value: '${_stats.reviewsWithImages}',
                label: 'Đánh giá có ảnh',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.trending_up,
                iconColor: const Color(0xFFE67E22),
                value: _stats.totalReviews > 0
                    ? '${(_stats.reviewsWithImages / _stats.totalReviews * 100).toStringAsFixed(0)}%'
                    : '0%',
                label: 'Tỷ lệ có ảnh',
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Summary Card ──────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Biểu đồ phân bố sao (Bar Chart) ──────────────────────────────────

class _StarDistributionChart extends StatelessWidget {
  final Map<int, int> distribution;
  final int total;

  const _StarDistributionChart({
    required this.distribution,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('Chưa có dữ liệu',
              style: TextStyle(color: AppColors.textLight)),
        ),
      );
    }

    final maxCount =
        distribution.values.fold<int>(1, (cur, v) => v > cur ? v : cur);

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          // Điểm trung bình lớn
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 28),
              const SizedBox(width: 6),
              Text(
                (distribution.entries
                            .fold<double>(
                                0, (sum, e) => sum + e.key * e.value) /
                        total)
                    .toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark),
              ),
              const SizedBox(width: 4),
              Text(
                '/ 5',
                style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Các hàng sao
          ...List.generate(5, (index) {
            final star = 5 - index; // Từ 5 sao xuống 1 sao
            final count = distribution[star] ?? 0;
            final ratio =
                maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$star sao',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFF0F0F0),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFB300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Biểu đồ xu hướng theo tháng ──────────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  final List<_MonthlyComparison> items;

  const _MonthlyTrendChart({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('Chưa có dữ liệu',
              style: TextStyle(color: AppColors.textLight)),
        ),
      );
    }

    final maxCount = items.fold<int>(
        1, (cur, item) => item.reviewCount > cur ? item.reviewCount : cur);

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          // Chú thích
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                  color: const Color(0xFF5B8DEF), label: 'Số lượng'),
              const SizedBox(width: 20),
              _LegendDot(
                  color: const Color(0xFFFFB300), label: 'Điểm TB'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _MonthlyTrendPainter(
                items: items,
                maxCount: maxCount,
              ),
            ),
          ),
          // Nhãn trục X
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: items
                  .map((item) => Expanded(
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textLight),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}

class _MonthlyTrendPainter extends CustomPainter {
  final List<_MonthlyComparison> items;
  final int maxCount;

  _MonthlyTrendPainter({
    required this.items,
    required this.maxCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final paintCount = Paint()
      ..color = const Color(0xFF5B8DEF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintRating = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    final w = size.width / items.length;
    final h = size.height - 10;

    // Đường số lượng
    final pathCount = Path();
    // Đường điểm TB
    final pathRating = Path();

    for (var i = 0; i < items.length; i++) {
      final x = w * i + w / 2;
      final yCount =
          h - (items[i].reviewCount / maxCount * h);
      final yRating = h - (items[i].avgRating / 5.0 * h);

      if (i == 0) {
        pathCount.moveTo(x, yCount);
        pathRating.moveTo(x, yRating);
      } else {
        pathCount.lineTo(x, yCount);
        pathRating.lineTo(x, yRating);
      }
    }

    canvas.drawPath(pathCount, paintCount);
    canvas.drawPath(pathRating, paintRating);

    // Vẽ dots
    for (var i = 0; i < items.length; i++) {
      final x = w * i + w / 2;
      final yCount =
          h - (items[i].reviewCount / maxCount * h);
      final yRating = h - (items[i].avgRating / 5.0 * h);

      dotPaint.color = const Color(0xFF5B8DEF);
      canvas.drawCircle(Offset(x, yCount), 3.5, dotPaint);
      dotPaint.color = const Color(0xFFFFB300);
      canvas.drawCircle(Offset(x, yRating), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── So sánh tháng ─────────────────────────────────────────────────────

class _MonthComparisonCard extends StatelessWidget {
  final int currentReviews;
  final int previousReviews;
  final double currentAvgRating;
  final double previousAvgRating;

  const _MonthComparisonCard({
    required this.currentReviews,
    required this.previousReviews,
    required this.currentAvgRating,
    required this.previousAvgRating,
  });

  @override
  Widget build(BuildContext context) {
    final reviewDiff = currentReviews - previousReviews;
    final reviewPercent = previousReviews > 0
        ? (reviewDiff / previousReviews * 100)
        : (currentReviews > 0 ? 100.0 : 0.0);
    final ratingDiff = currentAvgRating - previousAvgRating;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ComparisonTile(
                label: 'Tháng trước',
                reviews: previousReviews,
                avgRating: previousAvgRating,
                color: const Color(0xFFBDBDBD),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward,
                  color: AppColors.textLight, size: 20),
            ),
            Expanded(
              child: _ComparisonTile(
                label: 'Tháng này',
                reviews: currentReviews,
                avgRating: currentAvgRating,
                color: const Color(0xFF5B8DEF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DiffIndicator(
                icon: Icons.reviews_outlined,
                label: 'Số lượng',
                value:
                    '${reviewDiff >= 0 ? '+' : ''}$reviewDiff',
                percent: reviewPercent,
                isPositive: reviewDiff >= 0,
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFE0E0E0)),
              _DiffIndicator(
                icon: Icons.star_outline,
                label: 'Điểm TB',
                value:
                    '${ratingDiff >= 0 ? '+' : ''}${ratingDiff.toStringAsFixed(2)}',
                percent: previousAvgRating > 0
                    ? (ratingDiff / previousAvgRating * 100)
                    : 0,
                isPositive: ratingDiff >= 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  final String label;
  final int reviews;
  final double avgRating;
  final Color color;

  const _ComparisonTile({
    required this.label,
    required this.reviews,
    required this.avgRating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('$reviews',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star,
                  size: 12, color: Color(0xFFFFB300)),
              const SizedBox(width: 2),
              Text(avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiffIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double percent;
  final bool isPositive;

  const _DiffIndicator({
    required this.icon,
    required this.label,
    required this.value,
    required this.percent,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isPositive ? const Color(0xFF27AE60) : const Color(0xFFE05252);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Danh sách sản phẩm được đánh giá nhiều ────────────────────────────

class _TopReviewedList extends StatelessWidget {
  final List<_TopReviewedProduct> items;

  const _TopReviewedList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Chưa có dữ liệu',
          style: TextStyle(color: AppColors.textLight));
    }

    return Column(
      children: items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Số thứ tự
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                // Ảnh sản phẩm
                if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_outlined,
                            size: 20, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        size: 20, color: Colors.grey),
                  ),
                const SizedBox(width: 10),
                // Thông tin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${item.reviewCount} đánh giá',
                            style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.star,
                              size: 11,
                              color: const Color(0xFFFFB300)),
                          const SizedBox(width: 2),
                          Text(
                            item.avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Helper model ──────────────────────────────────────────────────────

class _ProductReviewAgg {
  final String name;
  int reviewCount;
  double totalRating;
  String? imageUrl;

  _ProductReviewAgg({
    required this.name,
    required this.reviewCount,
    required this.totalRating,
    this.imageUrl,
  });
}

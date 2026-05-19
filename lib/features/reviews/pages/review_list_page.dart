import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../orders/services/order_repository.dart';
import '../services/review_repository.dart';
import 'review_page.dart';

class ReviewListPage extends StatefulWidget {
  const ReviewListPage({super.key});

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  final OrderRepository _orderRepo = OrderRepository.instance;
  final ReviewRepository _reviewRepo = ReviewRepository.instance;
  Future<List<_ReviewEntry>>? _entriesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _entriesFuture = _loadEntries();
    });
  }

  Future<List<_ReviewEntry>> _loadEntries() async {
    final orders = await _orderRepo.getOrdersForCurrentUser(statusFilter: 'Completed');
    if (orders.isEmpty) return [];

    final reviewedFlags = await Future.wait(
      orders.map((order) => _reviewRepo.hasReviewed(order.invoiceId)),
    );

    return List.generate(
      orders.length,
      (index) => _ReviewEntry(order: orders[index], hasReviewed: reviewedFlags[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Danh gia don hang'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Chua danh gia'),
              Tab(text: 'Da danh gia'),
            ],
          ),
        ),
        body: FutureBuilder<List<_ReviewEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Loi: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final entries = snapshot.data ?? [];
            final pending = entries.where((e) => !e.hasReviewed).toList();
            final reviewed = entries.where((e) => e.hasReviewed).toList();

            return TabBarView(
              children: [
                _buildList(pending, emptyMessage: 'Chua co don hang can danh gia'),
                _buildList(reviewed, emptyMessage: 'Chua co danh gia nao'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<_ReviewEntry> entries, {required String emptyMessage}) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final order = entry.order;
          final statusText = entry.hasReviewed ? 'Da danh gia' : 'Chua danh gia';
          final statusColor = entry.hasReviewed ? Colors.green : Colors.orange;

          return Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReviewPage(invoiceId: order.invoiceId)),
                );
                if (mounted) {
                  _reload();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Don hang #${order.invoiceId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatPrice(order.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}d';
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _ReviewEntry {
  final OrderInfo order;
  final bool hasReviewed;

  _ReviewEntry({required this.order, required this.hasReviewed});
}

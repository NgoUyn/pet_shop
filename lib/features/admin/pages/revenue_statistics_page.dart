import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum RevenuePeriod { day, week, month, quarter, year }

class RevenueStatisticsPage extends StatefulWidget {
  const RevenueStatisticsPage({super.key});

  @override
  State<RevenueStatisticsPage> createState() => _RevenueStatisticsPageState();
}

class _RevenueStatisticsPageState extends State<RevenueStatisticsPage> {
  bool _loading = true;

  // Dữ liệu tổng quan
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalUsers = 0;
  int _totalProducts = 0;

  // Dữ liệu biểu đồ cột doanh thu
  List<_BarItem> _revenueBars = [];

  // Dữ liệu biểu đồ đường tăng trưởng
  List<_LineItem> _growthLine = [];

  // Dữ liệu biểu đồ tròn - trạng thái đơn hàng
  Map<String, int> _orderStatusMap = {};

  // Dữ liệu biểu đồ tròn - phân bố loại sản phẩm
  Map<String, int> _productTypeMap = {};

  // Dữ liệu biểu đồ tròn - tỷ lệ khách mới/cũ
  int _newCustomers = 0;
  int _returningCustomers = 0;

  // Top sản phẩm bán chạy
  List<_TopItem> _topProducts = [];
  List<_TopItem> _topPets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      final allOrders = snapshot.docs.map((doc) => doc.data()).toList();

      // Lọc đơn hàng đã thanh toán/hoàn thành
      final paidOrders = allOrders.where((data) {
        final paymentStatus = (data['paymentStatus'] as String? ?? '').toLowerCase();
        final orderStatus = (data['orderStatus'] as String? ?? '').toLowerCase();
        return paymentStatus == 'paid' ||
            paymentStatus == 'completed' ||
            orderStatus == 'completed' ||
            orderStatus == 'shipping';
      }).toList();

      // Tổng quan
      _totalRevenue = paidOrders.fold<double>(0, (t, d) => t + ((d['totalAmount'] as num?)?.toDouble() ?? 0));
      _totalOrders = paidOrders.length;

      // Đếm user từ orders
      final userIds = paidOrders.map((d) => d['customerFirebaseUid'] as String? ?? '').where((id) => id.isNotEmpty).toSet();
      _totalUsers = userIds.length;

      // Đếm sản phẩm từ items
      final productIds = <String>{};
      final petIds = <String>{};
      for (final data in paidOrders) {
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          if (itemMap['productId'] != null) productIds.add(itemMap['productId'].toString());
          if (itemMap['petId'] != null) petIds.add(itemMap['petId'].toString());
        }
      }
      _totalProducts = productIds.length + petIds.length;

      // Biểu đồ cột doanh thu 7 ngày
      _revenueBars = _buildRevenueBars(paidOrders);

      // Biểu đồ đường tăng trưởng 7 ngày
      _growthLine = _buildGrowthLine(paidOrders);

      // Biểu đồ tròn - trạng thái đơn hàng
      _orderStatusMap = _buildOrderStatusMap(allOrders);

      // Biểu đồ tròn - phân bố loại sản phẩm
      _productTypeMap = _buildProductTypeMap(paidOrders);

      // Tỷ lệ khách mới/cũ
      _newCustomers = _totalUsers;
      _returningCustomers = paidOrders
          .map((d) => d['customerFirebaseUid'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .fold<Map<String, int>>({}, (map, id) {
        map.update(id, (v) => v + 1, ifAbsent: () => 1);
        return map;
      }).values.where((c) => c > 1).length;

      // Top sản phẩm bán chạy
      _topProducts = _buildTopItems(paidOrders, isPet: false);
      _topPets = _buildTopItems(paidOrders, isPet: true);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_BarItem> _buildRevenueBars(List<Map<String, dynamic>> paidOrders) {
    final now = DateTime.now();
    final bars = <_BarItem>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      double revenue = 0;
      for (final data in paidOrders) {
        final createdAt = data['createdAt'] as String? ?? '';
        if (createdAt.isEmpty) continue;
        try {
          final date = DateTime.parse(createdAt);
          if (date.isAfter(day) && date.isBefore(nextDay)) {
            revenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
          }
        } catch (_) {}
      }
      bars.add(_BarItem(label: '${day.day}/${day.month}', value: revenue));
    }
    return bars;
  }

  List<_LineItem> _buildGrowthLine(List<Map<String, dynamic>> paidOrders) {
    final now = DateTime.now();
    final items = <_LineItem>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      double revenue = 0;
      int orders = 0;
      for (final data in paidOrders) {
        final createdAt = data['createdAt'] as String? ?? '';
        if (createdAt.isEmpty) continue;
        try {
          final date = DateTime.parse(createdAt);
          if (date.isAfter(day) && date.isBefore(nextDay)) {
            revenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
            orders++;
          }
        } catch (_) {}
      }
      items.add(_LineItem(label: '${day.day}/${day.month}', revenue: revenue, orders: orders));
    }
    return items;
  }

  Map<String, int> _buildOrderStatusMap(List<Map<String, dynamic>> allOrders) {
    final map = <String, int>{};
    for (final data in allOrders) {
      final status = (data['orderStatus'] as String? ?? 'unknown').toLowerCase();
      map.update(status, (v) => v + 1, ifAbsent: () => 1);
    }
    return map;
  }

  Map<String, int> _buildProductTypeMap(List<Map<String, dynamic>> paidOrders) {
    int petCount = 0;
    int productCount = 0;
    for (final data in paidOrders) {
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['petId'] != null) {
          petCount++;
        } else if (itemMap['productId'] != null) {
          productCount++;
        }
      }
    }
    return {'Thú cưng': petCount, 'Phụ kiện': productCount};
  }

  List<_TopItem> _buildTopItems(List<Map<String, dynamic>> paidOrders, {required bool isPet}) {
    final sales = <String, _TopItem>{};
    for (final data in paidOrders) {
      final items = data['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final isPetItem = itemMap['petId'] != null;
        if (isPetItem != isPet) continue;

        final name = (itemMap['productName'] as String? ?? itemMap['petName'] as String? ?? '').trim();
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
        if (name.isEmpty) continue;

        sales.update(
          name,
          (existing) => _TopItem(
            name: existing.name,
            soldCount: existing.soldCount + quantity,
            revenue: existing.revenue + quantity * unitPrice,
          ),
          ifAbsent: () => _TopItem(name: name, soldCount: quantity, revenue: quantity * unitPrice),
        );
      }
    }
    final list = sales.values.toList()..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return list.take(5).toList();
  }

  String _formatCurrency(double value) {
    final text = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buffer.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thống kê doanh thu'),
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
                  // 4 thẻ tổng quan
                  _buildSummaryRow(),
                  const SizedBox(height: 16),

                  // Biểu đồ cột doanh thu
                  _SectionCard(
                    title: 'Doanh thu 7 ngày',
                    child: _RevenueBarChart(items: _revenueBars),
                  ),
                  const SizedBox(height: 12),

                  // Biểu đồ đường tăng trưởng
                  _SectionCard(
                    title: 'Tăng trưởng doanh thu & đơn hàng',
                    child: _GrowthLineChart(items: _growthLine),
                  ),
                  const SizedBox(height: 12),

                  // Hàng: biểu đồ tròn trạng thái + phân bố sản phẩm
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SectionCard(
                          title: 'Trạng thái đơn',
                          child: _PieChart(data: _orderStatusMap, colors: _statusColors),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SectionCard(
                          title: 'Loại sản phẩm',
                          child: _PieChart(data: _productTypeMap, colors: _typeColors),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tỷ lệ khách mới/cũ
                  _SectionCard(
                    title: 'Khách hàng',
                    child: _NewVsReturningChart(
                      newCustomers: _newCustomers,
                      returningCustomers: _returningCustomers,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Top sản phẩm bán chạy
                  _SectionCard(
                    title: 'Top thú cưng bán chạy',
                    child: _TopItemsList(items: _topPets),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Top phụ kiện bán chạy',
                    child: _TopItemsList(items: _topProducts),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  static const _statusColors = [
    Color(0xFF2F80ED),
    Color(0xFF27AE60),
    Color(0xFFE05252),
    Color(0xFFF2994A),
    Color(0xFF9B51E0),
    Color(0xFFBDBDBD),
  ];

  static const _typeColors = [
    Color(0xFF5B8DEF),
    Color(0xFFF2994A),
  ];

  Widget _buildSummaryRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 360 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF5B8DEF),
                value: _formatCurrency(_totalRevenue),
                label: 'Doanh thu',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF2F80ED),
                value: '$_totalOrders',
                label: 'Đơn hàng',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.people_outline,
                iconColor: const Color(0xFF27AE60),
                value: '$_totalUsers',
                label: 'Người dùng',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFFF2994A),
                value: '$_totalProducts',
                label: 'Sản phẩm',
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

  const _SummaryCard({required this.icon, required this.iconColor, required this.value, required this.label});

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
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
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
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Biểu đồ cột doanh thu ─────────────────────────────────────────────

class _BarItem {
  final String label;
  final double value;
  _BarItem({required this.label, required this.value});
}

class _RevenueBarChart extends StatelessWidget {
  final List<_BarItem> items;
  const _RevenueBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<double>(1, (cur, item) => item.value > cur ? item.value : cur);
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final ratio = (item.value / maxValue).clamp(0.05, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_shortMoney(item.value), style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                  const SizedBox(height: 4),
                  Container(
                    height: 110,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8DC5A2), Color(0xFF2F7A44)]),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortMoney(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}tr';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}

// ─── Biểu đồ đường tăng trưởng ─────────────────────────────────────────

class _LineItem {
  final String label;
  final double revenue;
  final int orders;
  _LineItem({required this.label, required this.revenue, required this.orders});
}

class _GrowthLineChart extends StatelessWidget {
  final List<_LineItem> items;
  const _GrowthLineChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = items.fold<double>(1, (cur, item) => item.revenue > cur ? item.revenue : cur);
    final maxOrders = items.fold<int>(1, (cur, item) => item.orders > cur ? item.orders : cur);

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          // Chú thích
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFF2F7A44), label: 'Doanh thu'),
              const SizedBox(width: 20),
              _LegendDot(color: const Color(0xFF2F80ED), label: 'Đơn hàng'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _LineChartPainter(
                items: items,
                maxRevenue: maxRevenue,
                maxOrders: maxOrders.toDouble(),
              ),
            ),
          ),
          // Nhãn trục X
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: items.map((item) {
                return Expanded(
                  child: Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
                );
              }).toList(),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_LineItem> items;
  final double maxRevenue;
  final double maxOrders;

  _LineChartPainter({required this.items, required this.maxRevenue, required this.maxOrders});

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final paintRevenue = Paint()
      ..color = const Color(0xFF2F7A44)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintOrders = Paint()
      ..color = const Color(0xFF2F80ED)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill;

    final w = size.width / items.length;
    final h = size.height - 10;

    // Vẽ đường doanh thu
    final pathRevenue = Path();
    final pathOrders = Path();

    for (var i = 0; i < items.length; i++) {
      final x = w * i + w / 2;
      final yRevenue = h - (items[i].revenue / maxRevenue * h);
      final yOrders = h - (items[i].orders / maxOrders * h);

      if (i == 0) {
        pathRevenue.moveTo(x, yRevenue);
        pathOrders.moveTo(x, yOrders);
      } else {
        pathRevenue.lineTo(x, yRevenue);
        pathOrders.lineTo(x, yOrders);
      }
    }

    canvas.drawPath(pathRevenue, paintRevenue);
    canvas.drawPath(pathOrders, paintOrders);

    // Vẽ dots
    for (var i = 0; i < items.length; i++) {
      final x = w * i + w / 2;
      final yRevenue = h - (items[i].revenue / maxRevenue * h);
      final yOrders = h - (items[i].orders / maxOrders * h);

      dotPaint.color = const Color(0xFF2F7A44);
      canvas.drawCircle(Offset(x, yRevenue), 3.5, dotPaint);
      dotPaint.color = const Color(0xFF2F80ED);
      canvas.drawCircle(Offset(x, yOrders), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Biểu đồ tròn ──────────────────────────────────────────────────────

class _PieChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  const _PieChart({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (t, v) => t + v);
    if (total == 0) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Không có dữ liệu', style: TextStyle(color: AppColors.textLight, fontSize: 12))),
      );
    }

    return SizedBox(
      height: 180,
      child: Column(
        children: [
          // Biểu đồ tròn
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(100, 100),
              painter: _PieChartPainter(data: data, colors: colors, total: total),
            ),
          ),
          const SizedBox(height: 8),
          // Chú thích
          ...data.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final mapEntry = entry.value;
            final percent = total > 0 ? (mapEntry.value / total * 100).toStringAsFixed(0) : '0';
            final color = colors.length > idx ? colors[idx] : Colors.grey;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_statusLabel(mapEntry.key)}: $percent%',
                      style: const TextStyle(fontSize: 11, color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
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

  String _statusLabel(String key) {
    switch (key.toLowerCase()) {
      case 'completed':
        return 'Hoàn thành';
      case 'shipping':
        return 'Đang giao';
      case 'cancelled':
        return 'Đã hủy';
      case 'pending':
        return 'Chờ xử lý';
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'thú cưng':
        return 'Thú cưng';
      case 'phụ kiện':
        return 'Phụ kiện';
      default:
        return key;
    }
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;
  final int total;

  _PieChartPainter({required this.data, required this.colors, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -1.5708; // Bắt đầu từ trên
    final entries = data.entries.toList();

    for (var i = 0; i < entries.length; i++) {
      final sweepAngle = (entries[i].value / total) * 6.2832; // 2 * pi
      final paint = Paint()
        ..color = colors.length > i ? colors[i] : Colors.grey
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Vẽ lỗ trắng ở giữa
    canvas.drawCircle(center, radius * 0.45, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Biểu đồ khách mới/cũ ──────────────────────────────────────────────

class _NewVsReturningChart extends StatelessWidget {
  final int newCustomers;
  final int returningCustomers;
  const _NewVsReturningChart({required this.newCustomers, required this.returningCustomers});

  @override
  Widget build(BuildContext context) {
    final total = newCustomers + returningCustomers;
    if (total == 0) {
      return const Text('Không có dữ liệu', style: TextStyle(color: AppColors.textLight));
    }

    final newPercent = (newCustomers / total * 100).toStringAsFixed(0);
    final returnPercent = (returningCustomers / total * 100).toStringAsFixed(0);

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF5B8DEF), Color(0xFF2F80ED)]),
                      ),
                      child: Center(
                        child: Text('$newPercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Khách mới', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Text('$newCustomers', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: const Color(0xFFE0E0E0)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFE67E22)]),
                      ),
                      child: Center(
                        child: Text('$returnPercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Khách cũ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    Text('$returningCustomers', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Top sản phẩm ──────────────────────────────────────────────────────

class _TopItem {
  final String name;
  final int soldCount;
  final double revenue;
  _TopItem({required this.name, required this.soldCount, required this.revenue});
}

class _TopItemsList extends StatelessWidget {
  final List<_TopItem> items;
  const _TopItemsList({required this.items});

  String _formatCurrency(double value) {
    final text = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final fromEnd = text.length - i;
      buffer.write(text[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.textLight));
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
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${item.soldCount} lượt • ${_formatCurrency(item.revenue)}', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
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

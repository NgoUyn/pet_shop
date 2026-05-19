import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../services/order_repository.dart';

class OrderDetailItem {
  OrderDetailItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;
}

class OrderDetailPage extends StatefulWidget {
  final int invoiceId;

  const OrderDetailPage({super.key, required this.invoiceId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _isLoading = true;
  OrderInfo? _order;
  List<OrderDetailItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final order = await OrderRepository.instance.getOrderById(widget.invoiceId);
    final items = await _loadItems(widget.invoiceId, order);

    if (!mounted) return;
    setState(() {
      _order = order;
      _items = items;
      _isLoading = false;
    });
  }

  Future<List<OrderDetailItem>> _loadItems(int invoiceId, OrderInfo? order) async {
    try {
      final db = await AppDatabase.instance;
      final rows = await db.rawQuery(
        '''
        SELECT
          id.ProductID,
          id.PetID,
          id.Quantity,
          id.UnitPrice,
          p.ProductName,
          p.ImageURL AS ProductImageURL,
          pet.PetName,
          pet.ImageURL AS PetImageURL
        FROM InvoiceDetail id
        LEFT JOIN Product p ON id.ProductID = p.ProductID
        LEFT JOIN Pet pet ON id.PetID = pet.PetID
        WHERE id.InvoiceID = ?
        ''',
        [invoiceId],
      );

      if (rows.isEmpty) {
        return _buildItemsFromOrder(order);
      }

      return rows.map((r) {
        final pid = r['ProductID'] as int?;
        final name = (pid != null ? (r['ProductName'] as String?) : (r['PetName'] as String?)) ?? 'Sản phẩm';
        final imageUrl = (pid != null ? r['ProductImageURL'] : r['PetImageURL']) as String?;
        return OrderDetailItem(
          name: name,
          quantity: (r['Quantity'] as num?)?.toInt() ?? 1,
          unitPrice: (r['UnitPrice'] as num?)?.toDouble() ?? 0.0,
          imageUrl: imageUrl,
        );
      }).toList();
    } catch (_) {
      return _buildItemsFromOrder(order);
    }
  }

  List<OrderDetailItem> _buildItemsFromOrder(OrderInfo? order) {
    if (order == null) return [];
    return order.items.map((item) {
      return OrderDetailItem(
        name: item.displayName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        imageUrl: null,
      );
    }).toList();
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write('.');
    }
    return '${buffer.toString()}đ';
  }

  String _formatDate(String value) {
    try {
      final dt = DateTime.parse(value);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return value;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Unpaid':
        return Colors.orange;
      case 'Preparing':
        return Colors.blue;
      case 'Shipping':
        return Colors.purple;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeader() {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đơn hàng #${order.invoiceId}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.receipt_long, color: _statusColor(order.orderStatus)),
              const SizedBox(width: 8),
              Text(
                order.statusLabel,
                style: TextStyle(
                  color: _statusColor(order.orderStatus),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Ngày đặt', _formatDate(order.createdAt)),
          if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty)
            _buildInfoRow('Địa chỉ', order.shippingAddress!),
          _buildInfoRow('Thanh toán', order.paymentMethod ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems() {
    if (_items.isEmpty) {
      return const Text('Không có sản phẩm trong đơn hàng.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sản phẩm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl != null && item.imageUrl!.trim().isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackImage(),
                        )
                      : _fallbackImage(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SL: ${item.quantity} x ${_formatPrice(item.unitPrice)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined, size: 28, color: Colors.grey),
    );
  }

  Widget _buildTotal() {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Tổng cộng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(
          _formatPrice(order.totalAmount),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_order == null)
                    const Text('Không tìm thấy đơn hàng.')
                  else ...[
                    _buildHeader(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildItems(),
                    ),
                    const SizedBox(height: 12),
                    _buildTotal(),
                  ],
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../cart/pages/online_payment_page.dart';
import '../services/order_repository.dart';

class OrderHistoryPage extends StatefulWidget {
  final String? initialFilter;

  const OrderHistoryPage({super.key, this.initialFilter});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final OrderRepository _orderRepo = OrderRepository.instance;
  late Future<List<OrderInfo>> _ordersFuture;
  String? _currentFilter;

  final List<_FilterOption> _filters = [
    _FilterOption('Tất cả', null),
    _FilterOption('Chưa thanh toán', 'Unpaid'),
    _FilterOption('Đang chuẩn bị', 'Preparing'),
    _FilterOption('Đang vận chuyển', 'Shipping'),
    _FilterOption('Hoàn thành', 'Completed'),
    _FilterOption('Đã hủy', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _orderRepo.getOrdersForCurrentUser(statusFilter: _currentFilter);
    });
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Unpaid':
        return Icons.payment;
      case 'Preparing':
        return Icons.inventory_2_outlined;
      case 'Shipping':
        return Icons.local_shipping_outlined;
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử đơn hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _currentFilter == f.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _currentFilter = selected ? f.value : null;
                        });
                        _loadOrders();
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textDark,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Order list
          Expanded(
            child: FutureBuilder<List<OrderInfo>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Lỗi: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'Chưa có đơn hàng nào',
                          style: TextStyle(fontSize: 16, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderInfo order) {
    final statusColor = _statusColor(order.orderStatus);
    final statusIcon = _statusIcon(order.orderStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showOrderDetail(order);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order ID + Status
                Row(
                  children: [
                    Icon(statusIcon, size: 20, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      'Đơn hàng #${order.invoiceId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Items preview
                ...order.items.take(2).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.displayName,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'x${item.quantity}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )),
                if (order.items.length > 2)
                  Text(
                    '... và ${order.items.length - 2} sản phẩm khác',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),

                const SizedBox(height: 8),
                // Footer: Date + Total
                Row(
                  children: [
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(order.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetail(OrderInfo order) {
    final statusColor = _statusColor(order.orderStatus);
    final statusIcon = _statusIcon(order.orderStatus);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status header
                  Row(
                    children: [
                      Icon(statusIcon, size: 28, color: statusColor),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đơn hàng #${order.invoiceId}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            order.statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),

                  // Order info
                  _buildInfoRow('Ngày đặt', _formatDate(order.createdAt)),
                  if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty)
                    _buildInfoRow('Địa chỉ', order.shippingAddress!),
                  _buildInfoRow('Phương thức', order.paymentMethod ?? 'N/A'),
                  const SizedBox(height: 16),

                  // Items
                  const Text(
                    'Sản phẩm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.displayName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '${item.quantity} x ${_formatPrice(item.unitPrice)}',
                              style: const TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng cộng',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _formatPrice(order.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // Action buttons for unpaid or preparing orders
                  if (order.orderStatus == 'Unpaid' || order.orderStatus == 'Preparing') ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelOrderByCustomer(order),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Huỷ đơn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (order.orderStatus == 'Unpaid') ...[
                          const SizedBox(width: 12),
                          // Retry payment button (only for unpaid)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _retryPayment(order),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Thanh toán lại'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelOrderByCustomer(OrderInfo order) async {
    final isPaid = order.paymentStatus.trim().toLowerCase() == 'paid';
    final message = isPaid
      ? 'Đơn hàng #${order.invoiceId} đã được thanh toán. Nếu huỷ, shop sẽ liên hệ hướng dẫn hoàn tiền. Bạn có chắc muốn huỷ?'
      : 'Bạn có chắc muốn huỷ đơn hàng #${order.invoiceId}?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ đơn hàng'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orderRepo.cancelOrderByCustomer(order.invoiceId);
      if (!mounted) return;
      // Close bottom sheet first
      Navigator.pop(context);
      if (!mounted) return;
      // Then reload and show success
      _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPaid ? 'Đã huỷ đơn hàng! Vui lòng xem tin nhắn từ shop để được hướng dẫn hoàn tiền.' : 'Đã huỷ đơn hàng!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      print('CancelOrder error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('StateError: ', '').replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _retryPayment(OrderInfo order) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlinePaymentPage(
            subtotalAmount: order.totalAmount,
            discountAmount: 0,
            payableAmount: order.totalAmount,
            shippingAddress: order.shippingAddress,
            useLoyaltyPoints: false,
            existingInvoiceId: order.invoiceId,
          ),
        ),
      );

      if (!mounted) return;
      _loadOrders();
      // Close bottom sheet if payment was processed
      if (result != null) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return isoDate;
    }
  }
}

class _FilterOption {
  final String label;
  final String? value;

  _FilterOption(this.label, this.value);
}

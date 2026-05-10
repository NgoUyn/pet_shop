import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../chat/pages/admin_chat_inbox_page.dart';
import '../../orders/services/order_repository.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key});

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  final OrderRepository _orderRepo = OrderRepository.instance;
  late Future<List<OrderInfo>> _ordersFuture;
  String? _currentFilter;

  final List<_FilterOption> _filters = [
    _FilterOption('Tất cả', null),
    _FilterOption('Đang chuẩn bị', 'Preparing'),
    _FilterOption('Đang vận chuyển', 'Shipping'),
    _FilterOption('Hoàn thành', 'Completed'),
    _FilterOption('Đã hủy', 'Cancelled'),
    _FilterOption('Chưa thanh toán', 'Unpaid'),
  ];

  @override
  void initState() {
    super.initState();
    _currentFilter = 'Preparing'; // Default show preparing orders
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = _orderRepo.getAllOrders(statusFilter: _currentFilter);
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

  Future<void> _confirmPreparing(int invoiceId) async {
    try {
      await _orderRepo.confirmPreparing(invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận đơn hàng và chuyển sang vận chuyển!'), backgroundColor: Colors.green),
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markCompleted(int invoiceId) async {
    try {
      await _orderRepo.markCompleted(invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu đơn hàng hoàn thành!'), backgroundColor: Colors.green),
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelOrder(int invoiceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: const Text('Bạn có chắc muốn hủy đơn hàng này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orderRepo.cancelOrder(invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy đơn hàng!'), backgroundColor: Colors.orange),
      );
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminChatInboxPage()),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
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
                          'Không có đơn hàng nào',
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Đơn hàng #${order.invoiceId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
            const SizedBox(height: 8),

            // Customer info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  'Khách hàng #${order.invoiceId}', // We don't have customer name in OrderInfo yet
                  style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Items preview
            ...order.items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.productName ?? 'Sản phẩm',
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

            // Date + Total
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

            // Action buttons
            if (order.orderStatus == 'Preparing') ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelOrder(order.invoiceId),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Hủy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmPreparing(order.invoiceId),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Xác nhận'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (order.orderStatus == 'Shipping') ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelOrder(order.invoiceId),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Hủy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markCompleted(order.invoiceId),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Hoàn thành'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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

import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../services/payment_service.dart';
import '../services/cart_repository.dart';

class OnlinePaymentPage extends StatefulWidget {
  final double subtotalAmount;
  final double discountAmount;
  final double payableAmount;
  final String? shippingAddress;
  final bool useLoyaltyPoints;

  const OnlinePaymentPage({
    super.key,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.payableAmount,
    this.shippingAddress,
    required this.useLoyaltyPoints,
  });

  @override
  State<OnlinePaymentPage> createState() => _OnlinePaymentPageState();
}

class _OnlinePaymentPageState extends State<OnlinePaymentPage> {
  late PaymentLinkResponse? _paymentLink;
  bool _isLoading = true;
  String? _errorMessage;
  dynamic _orderId;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      setState(() => _isLoading = true);

      _orderId = DateTime.now().millisecondsSinceEpoch;

      final items = await CartRepository.instance.listProductEntriesForCurrentUser();

      final orderItems = items
          .map((item) => OrderItem(
                name: item.productName,
                quantity: item.quantity,
                price: item.unitPrice,
              ))
          .toList();

      _paymentLink = await PaymentService.createPaymentLink(
        amount: widget.payableAmount,
        orderId: _orderId.toString(),
        description: 'Pet Shop Order',
        items: orderItems,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        // Mở link thanh toán
        await PaymentService.openPaymentLink(_paymentLink!.checkoutUrl);

        // Bắt đầu kiểm tra trạng thái
        _startStatusCheck();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final status = await PaymentService.getPaymentStatus(_orderId);

        if (status.isPaid) {
          if (mounted) {
            timer.cancel();
            _statusCheckTimer = null;

            // Xử lý thanh toán thành công
            await _handlePaymentSuccess();
          }
        } else if (status.isCancelled || status.isFailed) {
          if (mounted) {
            timer.cancel();
            _statusCheckTimer = null;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thanh toán bị hủy hoặc thất bại'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        print('Error checking payment status: $e');
      }
    });
  }

  Future<void> _handlePaymentSuccess() async {
    try {
      // Tạo đơn hàng trong database
      final result = await CartRepository.instance.checkoutCurrentUser(
        paymentMethod: 'Bank Transfer',
        shippingAddress: widget.shippingAddress,
        useLoyaltyPoints: widget.useLoyaltyPoints,
      );

      if (mounted) {
        _statusCheckTimer?.cancel();
        _statusCheckTimer = null;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanh toán thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('StateError: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retryPayment() async {
    _initializePayment();
  }

  Future<void> _cancelPayment() async {
    try {
      if (_orderId != null) {
        await PaymentService.cancelPayment(_orderId);
      }
    } catch (e) {
      print('Error canceling payment: $e');
    }

    if (mounted) {
      _statusCheckTimer?.cancel();
      _statusCheckTimer = null;
      Navigator.pop(context);
    }
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

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelPayment();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán PayOS'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tạo link thanh toán...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _retryPayment,
                            child: const Text('Thử lại'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _cancelPayment,
                            child: const Text('Hủy'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Chi tiết thanh toán',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tạm tính:'),
                                    Text(_formatPrice(widget.subtotalAmount)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (widget.discountAmount > 0) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Giảm giá:'),
                                      Text(
                                        '- ${_formatPrice(widget.discountAmount)}',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tổng cộng:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _formatPrice(widget.payableAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.shippingAddress != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Địa chỉ giao hàng',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(widget.shippingAddress!),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Link PayOS đã được mở',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Vui lòng hoàn thành thanh toán trong trình duyệt. Chúng tôi sẽ tự động xác nhận khi thanh toán thành công.',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              TextButton(
                                onPressed: _cancelPayment,
                                child: const Text('Hủy thanh toán'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

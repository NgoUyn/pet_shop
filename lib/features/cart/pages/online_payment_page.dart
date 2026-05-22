import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../services/payment_service.dart';
import '../services/cart_repository.dart';

class OnlinePaymentPage extends StatefulWidget {
  final double subtotalAmount;
  final double discountAmount;
  final double payableAmount;
  final String? shippingAddress;
  final bool useLoyaltyPoints;
  final List<int>? selectedCartItemIds;

  /// If provided, skip creating a new pending order and use this existing invoice.
  /// Used for "Thanh toán lại" (retry payment) from order history.
  final int? existingInvoiceId;

  const OnlinePaymentPage({
    super.key,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.payableAmount,
    this.shippingAddress,
    required this.useLoyaltyPoints,
    this.selectedCartItemIds,
    this.existingInvoiceId,
  });

  @override
  State<OnlinePaymentPage> createState() => _OnlinePaymentPageState();
}

class _OnlinePaymentPageState extends State<OnlinePaymentPage> with WidgetsBindingObserver {
  late PaymentLinkResponse? _paymentLink;
  bool _isLoading = true;
  String? _errorMessage;
  dynamic _orderId;
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;
  int _countdownSeconds = 120; // 2 phút
  int? _invoiceId;
  bool _paymentCompleted = false;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePayment();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_paymentCompleted && !_isLoading) {
      _checkPaymentStatusNow();
    }
  }

  Future<void> _initializePayment() async {
    try {
      setState(() => _isLoading = true);

      // If existingInvoiceId is provided, use it (retry payment for existing unpaid order)
      if (widget.existingInvoiceId != null) {
        _invoiceId = widget.existingInvoiceId;
        // Use a new unique orderId for PayOS (invoiceId may have been used before)
        _orderId = '${_invoiceId}_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Bước 1: Tạo đơn hàng với trạng thái Unpaid ngay lập tức
        _invoiceId = await CartRepository.instance.createPendingOrder(
          shippingAddress: widget.shippingAddress,
          useLoyaltyPoints: widget.useLoyaltyPoints,
          selectedCartItemIds: widget.selectedCartItemIds,
        );
        _orderId = DateTime.now().millisecondsSinceEpoch;
      }

      List<OrderItem> orderItems;
      if (widget.existingInvoiceId != null) {
        // For retry payment, get items from the existing invoice
        final items = await CartRepository.instance.getUnpaidOrderItems(widget.existingInvoiceId!);
        orderItems = items
            .map((item) => OrderItem(
                  name: item.productName ?? item.petName ?? 'Sản phẩm',
                  quantity: item.quantity,
                  price: item.unitPrice,
                ))
            .toList();
      } else {
        final allItems = await CartRepository.instance.listProductEntriesForCurrentUser();
        final selected = widget.selectedCartItemIds;
        final items = (selected != null && selected.isNotEmpty)
          ? allItems.where((e) => selected.contains(e.cartItemId)).toList()
          : allItems;

        orderItems = items
            .map((item) => OrderItem(
                  name: item.productName,
                  quantity: item.quantity,
                  price: item.unitPrice,
                ))
            .toList();
      }

      _paymentLink = await PaymentService.createPaymentLink(
        amount: widget.payableAmount,
        orderId: _orderId.toString(),
        description: 'Pet Shop Order - #$_invoiceId',
        items: orderItems,
      );

      // Save payOSOrderId to Firestore for refund purposes
      if (_invoiceId != null && _paymentLink?.orderCode != null) {
        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(_invoiceId.toString())
              .set({
            'payOSOrderId': _paymentLink!.orderCode.toString(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isLoading = false);

        // Bắt đầu đếm ngược 2 phút
        _startCountdown();

        // Bắt đầu kiểm tra trạng thái
        _startStatusCheck();

        // Tạo WebView để load link thanh toán ngay trong app
        _initWebView(_paymentLink!.checkoutUrl);
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

  void _initWebView(String url) {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('WebView loading: $url');
          },
          onPageFinished: (String url) {
            print('WebView loaded: $url');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // Nếu URL chứa các từ khoá callback từ PayOS, tự động xử lý
            if (url.contains('success') || url.contains('paid')) {
              // Thanh toán thành công - kiểm tra ngay
              _checkPaymentStatusNow();
              return NavigationDecision.prevent;
            }

            if (url.contains('cancel') || url.contains('cancelled') || url.contains('fail')) {
              // Thanh toán thất bại hoặc bị hủy
              _checkPaymentStatusNow();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (mounted && !_paymentCompleted) {
          _statusCheckTimer?.cancel();
          _statusCheckTimer = null;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hết thời gian thanh toán. Đơn hàng sẽ được giữ trong 24h.'),
              backgroundColor: Colors.orange,
            ),
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context, {'invoiceId': _invoiceId, 'status': 'Unpaid'});
            }
          });
        }
      }
    });
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkPaymentStatusNow();
    });
  }

  Future<void> _checkPaymentStatusNow() async {
    if (_paymentCompleted || _orderId == null) return;

    try {
      final status = await PaymentService.getPaymentStatus(_orderId);

      if (status.isPaid) {
        if (mounted) {
          _statusCheckTimer?.cancel();
          _statusCheckTimer = null;
          await _handlePaymentSuccess();
        }
      } else if (status.isCancelled || status.isFailed) {
        if (mounted) {
          _statusCheckTimer?.cancel();
          _statusCheckTimer = null;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanh toán bị hủy hoặc thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_paymentCompleted) return;
    _paymentCompleted = true;

    try {
      _countdownTimer?.cancel();
      _countdownTimer = null;

      if (_invoiceId != null) {
        await CartRepository.instance.updateOrderToPaid(_invoiceId!);
      }

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
          Navigator.pop(context, {'invoiceId': _invoiceId, 'status': 'Paid'});
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
      _countdownTimer?.cancel();
      _countdownTimer = null;
      Navigator.pop(context, {'invoiceId': _invoiceId, 'status': 'Unpaid'});
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

  String get _formattedCountdown {
    final minutes = _countdownSeconds ~/ 60;
    final seconds = _countdownSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
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
          actions: [
            // Countdown timer ở AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 18,
                      color: _countdownSeconds <= 30 ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formattedCountdown,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _countdownSeconds <= 30 ? Colors.red : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tạo đơn hàng và link thanh toán...'),
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
                : Column(
                    children: [
                      // WebView thanh toán - chiếm phần lớn màn hình
                      Expanded(
                        child: _webViewController != null
                            ? WebViewWidget(controller: _webViewController!)
                            : const Center(child: CircularProgressIndicator()),
                      ),

                      // Thanh bottom với thông tin đơn hàng
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Mã đơn hàng: #$_invoiceId',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tổng: ${_formatPrice(widget.payableAmount)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _cancelPayment,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Hủy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

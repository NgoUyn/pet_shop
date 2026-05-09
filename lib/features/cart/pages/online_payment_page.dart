import 'package:flutter/material.dart';
import 'dart:async';
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

class _OnlinePaymentPageState extends State<OnlinePaymentPage> with WidgetsBindingObserver {
  PaymentLinkResponse? _paymentLink;
  bool _isLoading = true;
  String? _errorMessage;
  dynamic _orderId;
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;
  int _countdownSeconds = 120;
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

      _invoiceId = await CartRepository.instance.createPendingOrder(
        shippingAddress: widget.shippingAddress,
        useLoyaltyPoints: widget.useLoyaltyPoints,
      );

      _orderId = DateTime.now().millisecondsSinceEpoch;
      final items = await CartRepository.instance.listProductEntriesForCurrentUser();
      final orderItems = items.map((item) => OrderItem(
        name: item.productName,
        quantity: item.quantity,
        price: item.unitPrice,
      )).toList();

      _paymentLink = await PaymentService.createPaymentLink(
        amount: widget.payableAmount,
        orderId: _orderId.toString(),
        description: 'Pet Shop Order',
        items: orderItems,
      );

      if (mounted && _paymentLink != null) {
        _initWebView(_paymentLink!.checkoutUrl);
        _startCountdown();
        _startStatusCheck();
        setState(() => _isLoading = false);
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
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('success') || url.contains('paid')) {
              _checkPaymentStatusNow();
              return NavigationDecision.prevent;
            }
            if (url.contains('cancel') || url.contains('cancelled') || url.contains('fail')) {
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
      if (!mounted) { timer.cancel(); return; }
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _cancelPayment();
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
        await _handlePaymentSuccess();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_paymentCompleted) return;
    _paymentCompleted = true;
    _countdownTimer?.cancel();
    _statusCheckTimer?.cancel();

    if (_invoiceId != null) {
      await CartRepository.instance.updateOrderToPaid(_invoiceId!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green));
      Navigator.pop(context, {'invoiceId': _invoiceId, 'status': 'Paid'});
    }
  }

  Future<void> _cancelPayment() async {
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) Navigator.pop(context, {'invoiceId': _invoiceId, 'status': 'Unpaid'});
  }

  String _formatPrice(double value) {
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelPayment();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán PayOS'),
          actions: [
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_countdownSeconds ~/ 60}:${(_countdownSeconds % 60).toString().padLeft(2, '0')}', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ))
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    children: [
                      Expanded(child: _webViewController != null ? WebViewWidget(controller: _webViewController!) : const SizedBox()),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: const Offset(0, -2))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tổng: ${_formatPrice(widget.payableAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            TextButton(onPressed: _cancelPayment, child: const Text('Hủy', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

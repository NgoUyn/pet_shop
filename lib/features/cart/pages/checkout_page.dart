import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../profile/services/profile_repository.dart';
import '../../cart/services/cart_repository.dart';
import 'online_payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.selectedCartItemIds});

  final List<int>? selectedCartItemIds;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  ProfileData? _profile;
  List<CartProductEntry> _items = [];
  String _paymentMethod = 'COD';
  bool _useLoyaltyPoints = false;
  final TextEditingController _addressCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await ProfileRepository.instance.getCurrentProfile();
    final allItems = await CartRepository.instance.listProductEntriesForCurrentUser();
    final selected = widget.selectedCartItemIds;
    final items = (selected != null && selected.isNotEmpty)
        ? allItems.where((e) => selected.contains(e.cartItemId)).toList()
        : allItems;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _items = items;
      _addressCtrl.text = profile?.address ?? '';
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

  double get _total => _items.fold(0.0, (s, e) => s + e.lineTotal);

  int get _loyaltyPoints => _profile?.loyaltyPoints ?? 0;

  double get _maxRedeemableDiscount {
    if (_loyaltyPoints < 50) return 0;
    final redeemableBlocks = _loyaltyPoints ~/ 50;
    final maxBlocksByAmount = (_total / 5000).floor();
    final blocksToUse = redeemableBlocks > maxBlocksByAmount ? maxBlocksByAmount : redeemableBlocks;
    return blocksToUse * 5000.0;
  }

  double get _finalTotal {
    if (!_useLoyaltyPoints) return _total;
    return (_total - _maxRedeemableDiscount).clamp(0, double.infinity);
  }

  Future<void> _confirm() async {
    if (_items.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      if (_paymentMethod == 'Bank Transfer') {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnlinePaymentPage(
              subtotalAmount: _total,
              discountAmount: _useLoyaltyPoints ? _maxRedeemableDiscount : 0,
              payableAmount: _finalTotal,
              shippingAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
              useLoyaltyPoints: _useLoyaltyPoints,
              selectedCartItemIds: widget.selectedCartItemIds,
            ),
          ),
        );

        if (!mounted) return;
        // result is now a Map {'invoiceId': int, 'status': String}
        // Always pop back to the previous screen (cart or home)
        Navigator.pop(context, result);
        return;
      }

      final result = await CartRepository.instance.checkoutCurrentUser(
        paymentMethod: _paymentMethod,
        shippingAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        useLoyaltyPoints: _useLoyaltyPoints,
        selectedCartItemIds: widget.selectedCartItemIds,
      );
      if (!mounted) return;
      // Return success to caller
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))));
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đặt hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khách hàng', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_profile!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(_profile!.phone ?? '-', style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text('Địa chỉ nhận hàng', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Địa chỉ giao hàng'),
                    minLines: 2,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Điểm tích luỹ', style: Theme.of(context).textTheme.titleMedium),
                      Text('$_loyaltyPoints điểm', style: const TextStyle(color: AppColors.primary)),
                    ],
                  ),

                  if (_maxRedeemableDiscount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Bạn có muốn sử dụng điểm tích luỹ để giảm ${_formatPrice(_maxRedeemableDiscount)} không?',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _useLoyaltyPoints,
                      title: const Text('Có'),
                      onChanged: (v) => setState(() => _useLoyaltyPoints = v ?? false),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _useLoyaltyPoints,
                      title: const Text('Không'),
                      onChanged: (v) => setState(() => _useLoyaltyPoints = v ?? false),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Text('Phương thức thanh toán', style: Theme.of(context).textTheme.titleMedium),
                  RadioListTile<String>(
                    value: 'COD',
                    groupValue: _paymentMethod,
                    title: const Text('Thanh toán khi nhận hàng'),
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'COD'),
                  ),
                  RadioListTile<String>(
                    value: 'Bank Transfer',
                    groupValue: _paymentMethod,
                    title: const Text('Thanh toán trực tuyến (QR)'),
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'Bank Transfer'),
                  ),

                  const SizedBox(height: 12),
                  Text('Danh sách sản phẩm', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._items.map((e) => ListTile(
                        leading: SizedBox(width: 48, child: e.imageUrl == null || e.imageUrl!.isEmpty ? const Icon(Icons.image) : Image.network(e.imageUrl!, fit: BoxFit.cover)),
                        title: Text(e.productName),
                        subtitle: Text('${e.quantity} x ${_formatPrice(e.unitPrice)}'),
                        trailing: Text(_formatPrice(e.lineTotal)),
                      )),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_formatPrice(_finalTotal), style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  if (_useLoyaltyPoints && _maxRedeemableDiscount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giảm từ điểm', style: TextStyle(color: Colors.green)),
                        Text('-${_formatPrice(_maxRedeemableDiscount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirm,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                      child: _isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Xác nhận và thanh toán'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

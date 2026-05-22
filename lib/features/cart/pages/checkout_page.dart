import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/services/auth_session.dart';
import '../../profile/services/profile_repository.dart';
import '../../cart/services/cart_repository.dart';
import '../../admin/services/promotion_repository.dart';
import 'online_payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.selectedCartItemIds, this.directItem});

  final List<int>? selectedCartItemIds;

  /// If provided, this single item is used directly (bypasses cart loading).
  /// Used for "Mua" (Buy Now) button from product/pet cards.
  final CartProductEntry? directItem;

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

  // Promotion
  PromotionItemV2? _appliedPromotion;
  double _promoDiscount = 0;
  List<PromotionItemV2> _availablePromos = [];
  bool _isLoadingPromos = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await ProfileRepository.instance.getCurrentProfile();

    // If directItem is provided, use it directly (bypass cart loading)
    if (widget.directItem != null) {
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _items = [widget.directItem!];
        _addressCtrl.text = profile?.address ?? '';
      });
      _loadAvailablePromotions();
      return;
    }

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
    _loadAvailablePromotions();
  }

  Future<void> _loadAvailablePromotions() async {
    setState(() => _isLoadingPromos = true);
    try {
      // Load ALL promotions (not filtered by total)
      final all = await PromotionRepository.instance.listAll();
      print('_loadAvailablePromotions: total promotions from listAll: ${all.length}');
      for (final p in all) {
        print('  promo: id=${p.promotionId} code=${p.code} active=${p.isActive} minOrder=${p.minOrderValue} total=$_total');
      }

      // Filter: only active, not expired, and minOrderValue <= _total
      final valid = all.where((p) {
        if (!p.isActive) return false;
        if (_total < p.minOrderValue) return false;
        return true;
      }).toList();
      print('_loadAvailablePromotions: valid for order (total=$_total): ${valid.length}');

      final userId = AuthSession.instance.currentUserId.value;
      int? customerId;
      if (userId != null) {
        customerId = await PromotionRepository.instance.resolveCustomerId(userId);
        print('_loadAvailablePromotions: userId=$userId customerId=$customerId');
      }

      final available = <PromotionItemV2>[];
      for (final promo in valid) {
        if (customerId != null && customerId > 0) {
          final used = await PromotionRepository.instance.hasCustomerUsedPromo(promo.promotionId, customerId);
          print('_loadAvailablePromotions: promo ${promo.code} used=$used');
          if (used) continue;
        }
        available.add(promo);
      }

      print('_loadAvailablePromotions: final available: ${available.length}');
      if (mounted) {
        setState(() => _availablePromos = available);
      }
    } catch (e) {
      print('_loadAvailablePromotions error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPromos = false);
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
    double total = _total;
    if (_useLoyaltyPoints) {
      total -= _maxRedeemableDiscount;
    }
    if (_appliedPromotion != null) {
      total -= _promoDiscount;
    }
    return total.clamp(0, double.infinity);
  }

  /// For directItem purchases, first add the item to cart, then get its cartItemId.
  Future<int?> _ensureDirectItemInCart() async {
    final direct = widget.directItem!;
    if (direct.isPet && direct.petId != null) {
      await CartRepository.instance.addPetToCart(petId: direct.petId!);
    } else if (direct.productId != null) {
      await CartRepository.instance.addProductToCart(productId: direct.productId!, quantity: direct.quantity);
    } else {
      throw StateError('Không thể xác định loại sản phẩm');
    }

    // Reload cart items to get the newly added cartItemId
    final allItems = await CartRepository.instance.listProductEntriesForCurrentUser();
    // Find the matching item by productId or petId
    if (direct.isPet && direct.petId != null) {
      final match = allItems.where((e) => e.petId == direct.petId).toList();
      if (match.isNotEmpty) return match.first.cartItemId;
    } else if (direct.productId != null) {
      final match = allItems.where((e) => e.productId == direct.productId).toList();
      if (match.isNotEmpty) return match.first.cartItemId;
    }
    return null;
  }

  Future<void> _confirm() async {
    if (_items.isEmpty) return;

    final shippingAddress = _addressCtrl.text.trim();
    final phone = _profile?.phone?.trim() ?? '';

    debugPrint('--- UI Confirm Logic Debug ---');
    debugPrint('Profile exists: ${_profile != null}');
    debugPrint('Phone: "$phone"');
    debugPrint('Shipping Address: "$shippingAddress"');

    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin hồ sơ')),
      );
      return;
    }

    if (phone.isEmpty) {
      debugPrint('UI Validation failed: Phone is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng cập nhật số điện thoại trong hồ sơ trước khi đặt hàng')),
      );
      return;
    }

    if (shippingAddress.isEmpty) {
      debugPrint('UI Validation failed: Shipping Address is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ nhận hàng')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // For directItem purchases, add to cart first to get a cartItemId
      List<int>? checkoutItemIds = widget.selectedCartItemIds;
      if (widget.directItem != null) {
        final cartItemId = await _ensureDirectItemInCart();
        if (cartItemId != null) {
          checkoutItemIds = [cartItemId];
        }
      }

      if (_paymentMethod == 'Bank Transfer') {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnlinePaymentPage(
              subtotalAmount: _total,
              discountAmount: _useLoyaltyPoints ? _maxRedeemableDiscount : 0,
              payableAmount: _finalTotal,
              shippingAddress: shippingAddress,
              useLoyaltyPoints: _useLoyaltyPoints,
              selectedCartItemIds: checkoutItemIds,
              promotionCode: _appliedPromotion?.code,
              promotionDiscount: _promoDiscount,
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
        shippingAddress: shippingAddress,
        useLoyaltyPoints: _useLoyaltyPoints,
        selectedCartItemIds: checkoutItemIds,
        promotionCode: _appliedPromotion?.code,
        promotionDiscount: _promoDiscount,
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

  void _showPromoPicker() {
    // Find the best promotion (highest discountPercent)
    final bestPromo = _availablePromos.isEmpty
        ? null
        : _availablePromos.reduce((a, b) =>
            a.discountPercent > b.discountPercent ? a : b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Chọn ưu đãi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Chọn 1 ưu đãi để áp dụng cho đơn hàng', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availablePromos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final promo = _availablePromos[index];
                    final isBest = promo.promotionId == bestPromo?.promotionId;
                    final discount = promo.calculateDiscount(_total);
                    final discountText = 'Giảm ${promo.discountPercent.toStringAsFixed(0)}% (tối đa ${_formatPrice(promo.maxDiscount)})';

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isBest ? Colors.orange : Colors.grey[300]!,
                          width: isBest ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _appliedPromotion = promo;
                            _promoDiscount = discount;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Áp dụng mã ${promo.code} thành công! $discountText')),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Code badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isBest ? Colors.orange : AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  promo.code,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text(discountText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                                        if (isBest) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange, width: 1),
                                            ),
                                            child: const Text(
                                              'Tốt nhất',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Đơn tối thiểu ${_formatPrice(promo.minOrderValue)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    Text('Bạn tiết kiệm ${_formatPrice(discount)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              // Radio indicator
                              Icon(
                                Icons.radio_button_unchecked,
                                color: isBest ? Colors.orange : Colors.grey[400],
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
                  Text('Mã ưu đãi', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_isLoadingPromos)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ))
                  else if (_appliedPromotion != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_appliedPromotion!.code} - Giảm ${_appliedPromotion!.discountPercent.toStringAsFixed(0)}% (tối đa ${_formatPrice(_appliedPromotion!.maxDiscount)})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF27AE60)),
                                ),
                                Text(
                                  'Giảm ${_formatPrice(_promoDiscount)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF27AE60)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() {
                                _appliedPromotion = null;
                                _promoDiscount = 0;
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _availablePromos.isEmpty ? null : () => _showPromoPicker(),
                        icon: const Icon(Icons.local_offer_outlined, size: 20),
                        label: Text(_availablePromos.isEmpty ? 'Hiện không có ưu đãi' : 'Chọn ưu đãi'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

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

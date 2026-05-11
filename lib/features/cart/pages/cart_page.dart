import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../services/cart_repository.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartProductEntry> _items = [];
  bool _isLoading = true;
  bool _isCheckingOut = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data =
          await CartRepository.instance.listProductEntriesForCurrentUser();

      setState(() {
        _items = data;
        // Remove any selected IDs that no longer exist
        _selectedIds.removeWhere((id) => !data.any((e) => e.cartItemId == id));
      });
    } catch (e) {
      _showMessage('Không thể tải giỏ hàng');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateQty(
    CartProductEntry entry,
    int delta,
  ) async {
    final newQty = entry.quantity + delta;

    if (newQty < 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận'),
          content: Text('Xoá ${entry.productName} khỏi giỏ hàng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (ok == true) {
        await _removeItem(entry);
      }
      return;
    }

    if (entry.isPet && newQty > 1) {
      _showMessage('Thú cưng chỉ có thể mua 1 con');
      return;
    }

    if (!entry.isPet && newQty > entry.stockQuantity) {
      _showMessage('Số lượng vượt quá tồn kho');
      return;
    }

    try {
      await CartRepository.instance.updateQuantity(
        entry.cartItemId,
        newQty,
      );

      setState(() {
        final index = _items.indexWhere(
          (e) => e.cartItemId == entry.cartItemId,
        );

        if (index != -1) {
          _items[index] = CartProductEntry(
            cartItemId: entry.cartItemId,
            productId: entry.productId,
            petId: entry.petId,
            productName: entry.productName,
            imageUrl: entry.imageUrl,
            unitPrice: entry.unitPrice,
            quantity: newQty,
            stockQuantity: entry.stockQuantity,
            addedAt: entry.addedAt,
          );
        }
      });
    } catch (e) {
      _showMessage(
        e.toString().replaceAll(
          'StateError: ',
          '',
        ),
      );
    }
  }

  Future<void> _removeItem(
    CartProductEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Xoá ${entry.productName} khỏi giỏ hàng?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text(
              'Xoá',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await CartRepository.instance.removeFromCart(
        entry.cartItemId,
      );

      setState(() {
        _items.removeWhere(
          (e) => e.cartItemId == entry.cartItemId,
        );
        _selectedIds.remove(entry.cartItemId);
      });

      _showMessage('Đã xoá sản phẩm');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá ${_selectedIds.length} sản phẩm đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      for (final id in _selectedIds) {
        await CartRepository.instance.removeFromCart(id);
      }
      setState(() {
        _items.removeWhere((e) => _selectedIds.contains(e.cartItemId));
        _selectedIds.clear();
      });
      _showMessage('Đã xoá sản phẩm đã chọn');
    }
  }

  void _toggleSelection(int cartItemId) {
    setState(() {
      if (_selectedIds.contains(cartItemId)) {
        _selectedIds.remove(cartItemId);
      } else {
        _selectedIds.add(cartItemId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_items.map((e) => e.cartItemId));
      }
    });
  }

  Widget _buildImage(String? url) {
    final normalized = (url ?? '').trim();

    if (normalized.isEmpty) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.textLight,
          size: 34,
        ),
      );
    }

    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) {
        return Container(
          color: AppColors.background,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textLight,
            size: 34,
          ),
        );
      },
    );
  }

  String _formatPrice(double value) {
    final formatted =
        value.toStringAsFixed(0);

    final buffer = StringBuffer();

    for (var i = 0;
        i < formatted.length;
        i++) {
      final fromEnd = formatted.length - i;

      buffer.write(formatted[i]);

      if (fromEnd > 1 &&
          fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()}đ';
  }

  Widget _qtyBtn(
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          borderRadius:
              BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildRow(
    CartProductEntry entry,
  ) {
    final isSelected = _selectedIds.contains(entry.cartItemId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: isSelected
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      padding:
          const EdgeInsets.all(12),
      child: Row(
        children: [
          // Checkbox luôn hiển thị để chọn sản phẩm
          GestureDetector(
            onTap: () => _toggleSelection(entry.cartItemId),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                size: 24,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _toggleSelection(entry.cartItemId),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _buildImage(
                  entry.imageUrl,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.productName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color: AppColors
                              .textDark,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons
                            .delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () =>
                          _removeItem(
                        entry,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatPrice(
                    entry.unitPrice,
                  ),
                  style:
                      const TextStyle(
                    color: AppColors
                        .secondary,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    _qtyBtn(
                      Icons.remove,
                      () => _updateQty(
                        entry,
                        -1,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                      ),
                      child: Text(
                        '${entry.quantity}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      Icons.add,
                      entry.isPet
                          ? null
                          : () => _updateQty(
                                entry,
                                1,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      entry.isPet ? 'Thú cưng' : 'Kho: ${entry.stockQuantity}',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color: AppColors
                            .textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _selectedIds.isNotEmpty;
    final total = hasSelection
        ? _items
            .where((item) => _selectedIds.contains(item.cartItemId))
            .fold(0.0, (sum, item) => sum + item.lineTotal)
        : _items.fold(0.0, (sum, item) => sum + item.lineTotal);
    final hasCheckoutItems = hasSelection ? true : _items.isNotEmpty;

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                hasSelection ? 'Tổng đã chọn' : 'Tổng thanh toán',
                style: const TextStyle(
                  color:
                      AppColors.textLight,
                ),
              ),
              Text(
                _formatPrice(total),
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      AppColors.primary,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: (!hasCheckoutItems || _isCheckingOut)
              ? null
              : _checkout,
            style: ElevatedButton
                .styleFrom(
              backgroundColor:
                  AppColors.secondary,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 32,
                vertical: 12,
              ),
            ),
            child: Text(
              hasSelection ? 'Mua đã chọn (${_selectedIds.length})' : 'Mua hàng',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final userId =
        AuthSession.instance
            .currentUserId.value;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title:
            const Text('Giỏ hàng'),
        backgroundColor:
            AppColors.white,
        foregroundColor:
            AppColors.textDark,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty) ...[
            // Chọn tất cả / Bỏ chọn tất cả
            IconButton(
              icon: Icon(
                _selectedIds.length == _items.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              tooltip: _selectedIds.length == _items.length
                  ? 'Bỏ chọn tất cả'
                  : 'Chọn tất cả',
              onPressed: _selectAll,
            ),
            // Xoá các mục đã chọn
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: 'Xoá đã chọn',
                onPressed: _deleteSelected,
              ),
            // Tải lại
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loadCart,
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ],
      ),
      body: userId == null
          ? Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    'Vui lòng đăng nhập để xem giỏ hàng',
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  ElevatedButton(
                    onPressed:
                        () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginPage(),
                        ),
                      );

                      if (!mounted) {
                        return;
                      }

                      await CartRepository
                          .instance
                          .refreshCountForCurrentUser();

                      _loadCart();
                    },
                    child:
                        const Text(
                      'Đăng nhập',
                    ),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Giỏ hàng đang trống',
                      ),
                    )
                  : ListView
                      .separated(
                      padding:
                          const EdgeInsets
                              .all(16),
                      itemBuilder:
                          (
                            context,
                            index,
                          ) =>
                              _buildRow(
                        _items[index],
                      ),
                      separatorBuilder:
                          (
                            context,
                            index,
                          ) =>
                              const SizedBox(
                        height: 12,
                      ),
                      itemCount:
                          _items.length,
                    ),
      bottomNavigationBar:
          userId == null
              ? null
              : _buildBottomBar(),
    );
  }

  Future<void> _checkout() async {
    final selectedIds = _selectedIds.isNotEmpty ? _selectedIds.toList() : null;

    // Navigate to dedicated checkout page for full confirmation
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(selectedCartItemIds: selectedIds),
      ),
    );

    if (result == null) return;

    if (!mounted) return;
    await _loadCart();

    // result can be CheckoutResult (COD) or Map (Bank Transfer)
    String dialogTitle;
    String dialogContent;

    if (result is CheckoutResult) {
      dialogTitle = 'Đặt hàng thành công';
      dialogContent = 'Mã đơn hàng: #${result.invoiceId}\nSố lượng: ${result.totalItems}\nTổng tiền: ${_formatPrice(result.totalAmount)}\nTích luỹ: +${result.earnedPoints} điểm';
    } else if (result is Map) {
      final invoiceId = result['invoiceId'];
      final status = result['status'];
      if (status == 'Paid') {
        dialogTitle = 'Thanh toán thành công';
        dialogContent = 'Mã đơn hàng: #$invoiceId\nCảm ơn bạn đã mua hàng!';
      } else {
        dialogTitle = 'Đơn hàng đã tạo';
        dialogContent = 'Mã đơn hàng: #$invoiceId\nĐơn hàng đang chờ thanh toán. Vui lòng thanh toán trong vòng 24h.';
      }
    } else {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

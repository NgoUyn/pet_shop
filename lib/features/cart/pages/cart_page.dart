import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../services/cart_repository.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Future<List<CartProductEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = CartRepository.instance.listProductEntriesForCurrentUser();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2), // Thông báo tự tắt sau 2s
      ),
    );
  }

  Future<void> _updateQty(CartProductEntry entry, int delta) async {
    final newQty = entry.quantity + delta;
    try {
      await CartRepository.instance.updateQuantity(entry.cartItemId, newQty);
      _reload();
    } catch (e) {
      _showMessage(e.toString().replaceAll('StateError: ', ''));
    }
  }

  Future<void> _removeItem(CartProductEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xoá ${entry.productName} khỏi giỏ hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      await CartRepository.instance.removeFromCart(entry.cartItemId);
      _reload();
      _showMessage('Đã xoá sản phẩm');
    }
  }

  Widget _buildImage(String? url) {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.textLight, size: 34),
      );
    }

    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.background,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 34),
        );
      },
    );
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '$bufferđ';
  }

  Widget _buildRow(CartProductEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: _buildImage(entry.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _removeItem(entry),
                    ),
                  ],
                ),
                Text(
                  _formatPrice(entry.unitPrice),
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () => _updateQty(entry, -1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${entry.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    _qtyBtn(Icons.add, () => _updateQty(entry, 1)),
                    const Spacer(),
                    Text('Kho: ${entry.stockQuantity}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthSession.instance.currentUserId.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: userId == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Vui lòng đăng nhập để xem giỏ hàng'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                      if (!mounted) return;
                      await CartRepository.instance.refreshCountForCurrentUser();
                      _reload();
                    },
                    child: const Text('Đăng nhập'),
                  ),
                ],
              ),
            )
          : FutureBuilder<List<CartProductEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Không thể tải giỏ hàng'));
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('Giỏ hàng đang trống'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _buildRow(items[index]),
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemCount: items.length,
                );
              },
            ),
      bottomNavigationBar: userId == null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return FutureBuilder<List<CartProductEntry>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final total = items.fold(0.0, (sum, item) => sum + item.lineTotal);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng thanh toán', style: TextStyle(color: AppColors.textLight)),
                  Text(_formatPrice(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              ElevatedButton(
                onPressed: items.isEmpty ? null : () {},
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                child: const Text('Mua hàng', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}

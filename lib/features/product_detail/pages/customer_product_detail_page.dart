import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../cart/services/cart_repository.dart';
import '../../home/services/product_repository.dart';
import '../widgets/customer_bottom_action.dart';
import '../widgets/product_detail_body.dart';

/// Customer product detail page with chat/order/purchase actions.
/// Uses the shared [ProductDetailBody] for common display content
/// and [CustomerBottomAction] for customer-specific floating buttons.
class CustomerProductDetailPage extends StatefulWidget {
  const CustomerProductDetailPage({
    super.key,
    required this.product,
  });

  final ProductItem product;

  @override
  State<CustomerProductDetailPage> createState() => _CustomerProductDetailPageState();
}

class _CustomerProductDetailPageState extends State<CustomerProductDetailPage> {
  late ProductItem _currentProduct;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  void _onChatPressed() {
    // TODO: Implement chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chat đang được phát triển')),
    );
  }

  Future<void> _onOrderPressed() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);
    try {
      await CartRepository.instance.addProductToCart(productId: _currentProduct.productId, quantity: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _onBuyPressed() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);
    try {
      await CartRepository.instance.addProductToCart(productId: _currentProduct.productId, quantity: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _onRelatedProductTap(ProductItem product) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProductDetailPage(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết phụ kiện'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ProductDetailBody(
          product: _currentProduct,
          showAdminActions: false,
          onRelatedProductTap: _onRelatedProductTap,
          onProductChanged: (updated) {
            setState(() {
              _currentProduct = updated;
            });
          },
        ),
      ),
      bottomNavigationBar: CustomerBottomAction(
        onChatPressed: _onChatPressed,
        onOrderPressed: _onOrderPressed,
        onBuyPressed: _onBuyPressed,
      ),
    );
  }
}

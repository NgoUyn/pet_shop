import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../admin/pages/admin_product_form_page.dart';
import '../../home/services/product_repository.dart';
import '../widgets/product_detail_body.dart';

/// Admin product detail page with edit/delete actions.
/// When [readOnly] is true, hides edit/delete buttons for read-only view.
/// Uses the shared [ProductDetailBody] for common display content.
class AdminProductDetailPage extends StatefulWidget {
  const AdminProductDetailPage({
    super.key,
    required this.product,
    this.readOnly = false,
  });

  final ProductItem product;
  final bool readOnly;

  @override
  State<AdminProductDetailPage> createState() => _AdminProductDetailPageState();
}

class _AdminProductDetailPageState extends State<AdminProductDetailPage> {
  late ProductItem _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  Future<void> _editProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProductFormPage(product: _currentProduct),
      ),
    );

    if (changed != true || !mounted) return;

    // Refresh product data from database for real-time sync
    final refreshed = await ProductRepository.instance.getProductById(_currentProduct.productId);
    if (!mounted || refreshed == null) return;

    setState(() {
      _currentProduct = refreshed;
    });
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phụ kiện'),
        content: const Text('Bạn có chắc chắn muốn xóa phụ kiện này không? Sản phẩm sẽ bị ẩn khỏi cửa hàng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ProductRepository.instance.deleteProduct(_currentProduct.productId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  void _onRelatedProductTap(ProductItem product) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminProductDetailPage(product: product, readOnly: widget.readOnly),
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
          showAdminActions: !widget.readOnly,
          onEditPressed: widget.readOnly ? null : _editProduct,
          onDeletePressed: widget.readOnly ? null : _deleteProduct,
          onRelatedProductTap: _onRelatedProductTap,
          onProductChanged: (updated) {
            setState(() {
              _currentProduct = updated;
            });
          },
        ),
      ),
    );
  }
}

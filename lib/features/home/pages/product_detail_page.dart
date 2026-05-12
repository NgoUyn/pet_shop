import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../admin/pages/admin_product_form_page.dart';
import '../services/product_repository.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product, this.showAdminActions = false});

  final ProductItem product;
  final bool showAdminActions;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late ProductItem _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
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

  String _formatDateTime(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  Widget _buildHeroImage(ProductItem product) {
    final imageUrl = (product.imageUrl ?? '').trim();

    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 96,
                color: Color(0xFF2F80ED),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 96,
                    color: Color(0xFF2F80ED),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Times New Roman',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Times New Roman',
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {Color background = const Color(0xFFF2F8F4), Color foreground = const Color(0xFF3E7C63)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Times New Roman',
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Times New Roman',
          ),
        ),
      ),
    );
  }

  Future<void> _editProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminProductFormPage(product: _currentProduct)),
    );
    if (changed != true || !mounted) return;

    try {
      final updated = await ProductRepository.instance.getProductById(_currentProduct.productId);
      if (updated == null) return;
      if (!mounted) return;
      setState(() {
        _currentProduct = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa phụ kiện'),
        content: const Text('Bạn có chắc chắn muốn xóa phụ kiện này không?'),
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

    if (confirmed != true) return;

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

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    final description = (product.description ?? '').trim();
    final categoryFuture = ProductRepository.instance.getCategoryName(product.categoryId);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(product),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: FutureBuilder<String?>(
                future: categoryFuture,
                builder: (context, snapshot) {
                  final categoryName = snapshot.data;
                  final isNarrow = MediaQuery.sizeOf(context).width < 720;
                  final statusText = !product.isActive
                      ? 'Không bán'
                      : product.stockQuantity <= 0
                          ? 'Hết hàng'
                          : 'Đang bán';
                  final statusBackground = statusText == 'Đang bán'
                      ? const Color(0xFFEAF3FF)
                      : statusText == 'Hết hàng'
                          ? const Color(0xFFFFF4E5)
                          : const Color(0xFFF3F4F6);
                  final statusForeground = statusText == 'Đang bán'
                      ? const Color(0xFF2F80ED)
                      : statusText == 'Hết hàng'
                          ? const Color(0xFFB45309)
                          : const Color(0xFF6B7280);

                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.productName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Times New Roman',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (widget.showAdminActions)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildActionButton(
                                    label: 'Chỉnh sửa',
                                    icon: Icons.edit_outlined,
                                    background: const Color(0xFFEAF3FF),
                                    foreground: const Color(0xFF2F80ED),
                                    onPressed: _editProduct,
                                  ),
                                  _buildActionButton(
                                    label: 'Xóa',
                                    icon: Icons.delete_outline,
                                    background: const Color(0xFFFDECEC),
                                    foreground: const Color(0xFFB42318),
                                    onPressed: _deleteProduct,
                                  ),
                                ],
                              ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.productName,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Times New Roman',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (widget.showAdminActions)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildActionButton(
                                    label: 'Chỉnh sửa',
                                    icon: Icons.edit_outlined,
                                    background: const Color(0xFFEAF3FF),
                                    foreground: const Color(0xFF2F80ED),
                                    onPressed: _editProduct,
                                  ),
                                  _buildActionButton(
                                    label: 'Xóa',
                                    icon: Icons.delete_outline,
                                    background: const Color(0xFFFDECEC),
                                    foreground: const Color(0xFFB42318),
                                    onPressed: _deleteProduct,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (!widget.showAdminActions)
                        _buildBadge(
                          statusText,
                          background: statusBackground,
                          foreground: statusForeground,
                        ),
                      const SizedBox(height: 18),
                      _buildInfoRow('Mã phụ kiện', product.productId.toString()),
                      _buildInfoRow('Danh mục', categoryName?.isNotEmpty == true ? categoryName! : product.categoryId.toString()),
                      _buildInfoRow('Tồn kho', product.stockQuantity.toString()),
                      _buildInfoRow('Trạng thái', product.isActive ? 'Đang bán' : 'Ngừng bán'),
                      _buildInfoRow('Ngày tạo', _formatDateTime(product.createdAt.toLocal())),
                      if (description.isNotEmpty) ...[
                        const Text(
                          'Mô tả',
                          style: TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 15,
                            height: 1.45,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                      ],
                    ],
                  );

                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(product.price),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          fontFamily: 'Times New Roman',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildBadge(
                        statusText,
                        background: statusBackground,
                        foreground: statusForeground,
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 20),
                        rightColumn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(child: rightColumn),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

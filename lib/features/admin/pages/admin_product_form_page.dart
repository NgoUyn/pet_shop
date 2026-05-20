import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../../home/services/product_repository.dart';
import '../services/category_repository.dart';

class AdminProductFormPage extends StatefulWidget {
  const AdminProductFormPage({super.key, this.product});

  final ProductItem? product;

  @override
  State<AdminProductFormPage> createState() => _AdminProductFormPageState();
}

class _AdminProductFormPageState extends State<AdminProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _status = 'Đang bán';
  String? _imagePath;
  bool _isSaving = false;
  int? _selectedSubCategoryId;
  List<ProductSubCategory> _subCategories = const [];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _productNameController.text = product.productName;
      _priceController.text = product.price.toStringAsFixed(0);
      _stockController.text = product.stockQuantity.toString();
      _descriptionController.text = product.description ?? '';
      _selectedSubCategoryId = product.subCategoryId;
      _status = _deriveStatus(product);
    }
    _loadSubCategories();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _deriveStatus(ProductItem product) {
    if (!product.isActive) return 'Ngưng bán';
    if (product.stockQuantity < 5) return 'Hết hàng';
    return 'Đang bán';
  }

  Future<void> _loadSubCategories() async {
    final subs = await CategoryRepository.instance.listSubCategories();
    if (!mounted) return;
    setState(() {
      _subCategories = subs;
      if (_selectedSubCategoryId == null && subs.isNotEmpty) {
        _selectedSubCategoryId = subs.first.subCategoryId;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _imagePath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EF)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 44, color: Color(0xFF9AA5B1)),
          SizedBox(height: 8),
          Text(
            'Chưa chọn ảnh',
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasNewImage = (_imagePath?.trim().isNotEmpty == true);
    final existingUrl = widget.product?.imageUrl ?? '';
    final hasExistingImage = existingUrl.isNotEmpty && (existingUrl.startsWith('http://') || existingUrl.startsWith('https://'));

    Widget imageWidget;
    if (hasNewImage) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(_imagePath!.trim()),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
        ),
      );
    } else if (hasExistingImage) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          existingUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
        ),
      );
    } else {
      imageWidget = _buildPreviewPlaceholder();
    }

    // Wrap in a tappable InkWell so users can tap the image to change it
    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          imageWidget,
          // Semi-transparent overlay with "Change image" text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    hasNewImage || hasExistingImage ? 'Chạm để đổi ảnh' : 'Chạm để thêm ảnh',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      // Upload to Cloudinary if a new image was picked, otherwise use existing URL
      String? imageUrl;
      if (_imagePath?.trim().isNotEmpty == true) {
        imageUrl = await CloudinaryHelper.uploadImage(_imagePath!.trim());
        if (imageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải ảnh lên Cloudinary. Vui lòng thử lại.')),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else {
        imageUrl = widget.product?.imageUrl;
      }

      final enteredStock = int.parse(_stockController.text.trim());
      final status = _status;
      final isActive = status != 'Ngưng bán';
      final stockQuantity = status == 'Hết hàng' ? 0 : enteredStock;

      if (_isEditing) {
        await ProductRepository.instance.updateProduct(
          productId: widget.product!.productId,
          categoryId: widget.product!.categoryId,
          productName: _productNameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          stockQuantity: stockQuantity,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
          isActive: isActive,
          subCategoryId: _selectedSubCategoryId,
          status: status,
        );
      } else {
        await ProductRepository.instance.addProduct(
          categoryId: 1,
          productName: _productNameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          stockQuantity: stockQuantity,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
          isActive: isActive,
          subCategoryId: _selectedSubCategoryId,
          status: status,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu cập nhật: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa phụ kiện' : 'Thêm phụ kiện'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImagePreview(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _productNameController,
                        label: 'Tên phụ kiện',
                        hintText: 'Ví dụ: Vòng cổ chó da cao cấp',
                        validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên phụ kiện' : null,
                      ),
                      const SizedBox(height: 12),
                      // ── Sub Category ────────────────────────────────────────
                      if (_subCategories.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: _selectedSubCategoryId,
                          decoration: InputDecoration(
                            labelText: 'Loại phụ kiện',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            prefixIcon: const Icon(Icons.category_outlined),
                          ),
                          items: _subCategories
                              .map((s) => DropdownMenuItem<int>(
                                    value: s.subCategoryId,
                                    child: Text(s.subCategoryName),
                                  ))
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() => _selectedSubCategoryId = value),
                        ),
                      const SizedBox(height: 12),
                      // ── Description ─────────────────────────────────────────
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Mô tả',
                        hintText: 'Mô tả chi tiết về phụ kiện',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      // ── Quantity & Price (side by side) ─────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stockController,
                              label: 'Số lượng',
                              hintText: '18',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = int.tryParse((value ?? '').trim());
                                if (parsed == null || parsed < 0) {
                                  return 'Vui lòng nhập số lượng hợp lệ';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _priceController,
                              label: 'Giá',
                              hintText: '150000',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = double.tryParse((value ?? '').trim());
                                if (parsed == null || parsed <= 0) {
                                  return 'Vui lòng nhập giá hợp lệ';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Đang bán', child: Text('Đang bán')),
                          DropdownMenuItem(value: 'Hết hàng', child: Text('Hết hàng')),
                          DropdownMenuItem(value: 'Ngưng bán', child: Text('Ngưng bán')),
                        ],
                        onChanged: _isSaving ? null : (value) {
                          if (value == null) return;
                          setState(() {
                            _status = value;
                            if (value == 'Hết hàng') {
                              _stockController.text = '0';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProduct,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Đang lưu...' : (_isEditing ? 'Cập nhật phụ kiện' : 'Lưu phụ kiện')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}


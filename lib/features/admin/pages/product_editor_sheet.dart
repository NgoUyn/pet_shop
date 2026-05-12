import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/db/app_database.dart';
import '../../home/services/product_repository.dart';

class ProductEditorResult {
  ProductEditorResult({
    required this.categoryId,
    required this.productName,
    required this.price,
    required this.stockQuantity,
    this.description,
    this.imageUrl,
  });

  final int categoryId;
  final String productName;
  final double price;
  final int stockQuantity;
  final String? description;
  final String? imageUrl;
}

Future<ProductEditorResult?> showProductEditorSheet(
  BuildContext context, {
  required String title,
  ProductItem? initialProduct,
}) async {
  final db = await AppDatabase.instance;
  final rows = await db.query(
    'Category',
    columns: ['CategoryID', 'CategoryName'],
    orderBy: 'CategoryName ASC',
  );
  final categories = rows
      .map(
        (row) => _CategoryChoice(
          id: row['CategoryID'] as int,
          name: (row['CategoryName'] as String?) ?? '',
        ),
      )
      .toList();

  if (categories.isEmpty) {
    return null;
  }

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: initialProduct?.productName ?? '');
  final priceController = TextEditingController(text: initialProduct == null ? '' : initialProduct.price.toStringAsFixed(0));
  final stockController = TextEditingController(text: initialProduct?.stockQuantity.toString() ?? '1');
  final descriptionController = TextEditingController(text: initialProduct?.description ?? '');
  final imageUrlController = TextEditingController(text: initialProduct?.imageUrl ?? '');
  int? selectedCategoryId = initialProduct?.categoryId ?? categories.first.id;

  if (!context.mounted) {
    return null;
  }

  try {
    return await showModalBottomSheet<ProductEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setSheetState(() => selectedCategoryId = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Giá', border: OutlineInputBorder()),
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) return 'Vui lòng nhập giá hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tồn kho', border: OutlineInputBorder()),
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) return 'Vui lòng nhập tồn kho hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: imageUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'URL ảnh', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        if (selectedCategoryId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chưa có danh mục phù hợp')),
                          );
                          return;
                        }

                        Navigator.pop(
                          sheetContext,
                          ProductEditorResult(
                            categoryId: selectedCategoryId!,
                            productName: nameController.text.trim(),
                            price: double.parse(priceController.text.trim()),
                            stockQuantity: int.parse(stockController.text.trim()),
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                            imageUrl: imageUrlController.text.trim().isEmpty
                                ? null
                                : imageUrlController.text.trim(),
                          ),
                        );
                      },
                      child: Text(title),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
  }
}

class _CategoryChoice {
  _CategoryChoice({required this.id, required this.name});

  final int id;
  final String name;
}